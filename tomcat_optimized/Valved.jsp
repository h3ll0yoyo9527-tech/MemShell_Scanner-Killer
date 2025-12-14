<%@ page import="java.net.URL" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.io.InputStream" %>
<%@ page import="java.io.ByteArrayOutputStream" %>
<%@ page import="org.apache.catalina.Pipeline" %>
<%@ page import="org.apache.catalina.Valve" %>
<%@ page import="java.io.OutputStream" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Tomcat-Valve Memshell Scanner/Killer</title>
</head>
<body>
<center>
    <div>
        <%!
            // 获取StandardContext对象
            public Object getStandardContext(HttpServletRequest request) throws Exception {
                Object context = request.getSession().getServletContext();
                Field contextField = context.getClass().getDeclaredField("context");
                contextField.setAccessible(true);
                Object appContext = contextField.get(context);
                Field standardContextField = appContext.getClass().getDeclaredField("context");
                standardContextField.setAccessible(true);
                return standardContextField.get(appContext);
            }

            // 从StandardContext获取Pipeline
            public Pipeline getPipeline(Object standardContext) throws Exception {
                Method getPipelineMethod = standardContext.getClass().getMethod("getPipeline");
                getPipelineMethod.setAccessible(true);
                return (Pipeline) getPipelineMethod.invoke(standardContext);
            }

            // 获取Pipeline中的所有Valve
            public Valve[] getValves(HttpServletRequest request) throws Exception {
                Pipeline pipeline = getPipeline(getStandardContext(request));
                return pipeline.getValves();
            }

            // 获取Pipeline中的基础Valve
            public Valve getBasicValve(HttpServletRequest request) throws Exception {
                Pipeline pipeline = getPipeline(getStandardContext(request));
                return pipeline.getBasic();
            }

            // 删除指定Valve
            public synchronized void deleteValve(HttpServletRequest request, String valveClassName) throws Exception {
                Pipeline pipeline = getPipeline(getStandardContext(request));
                Valve[] valves = pipeline.getValves();

                for (Valve valve : valves) {
                    if (valve.getClass().getName().equals(valveClassName)) {
                        pipeline.removeValve(valve);
                        break;
                    }
                }
            }

            // 检查Valve是否为容器必要组件
            public boolean isEssentialValve(Valve valve, Valve basicValve) {
                return valve == basicValve ||
                        valve.getClass().getName().startsWith("org.apache.catalina.core.") ||
                        valve.getClass().getName().startsWith("org.apache.catalina.valves.");
            }

            // 检查类文件是否存在
            String classFileIsExists(Class<?> clazz) {
                if (clazz == null) return "class is null";
                String classNamePath = clazz.getName().replace(".", "/") + ".class";
                ClassLoader classLoader = clazz.getClassLoader();
                if (classLoader == null) {
                    return "Bootstrap ClassLoader";
                }
                URL url = classLoader.getResource(classNamePath);
                if (url == null) {
                    return "内存马嫌疑（无磁盘文件）";
                } else if (url.getProtocol().equals("jar")) {
                    return "来自JAR包：" + url.getPath();
                } else {
                    return "磁盘路径：" + url.getPath();
                }
            }

            // 获取类字节码
            byte[] getClassBytes(Class<?> clazz) throws Exception {
                String resourcePath = clazz.getName().replace('.', '/') + ".class";
                InputStream in = null;

                try {
                    // 尝试通过类加载器获取资源
                    if (clazz.getClassLoader() != null) {
                        in = clazz.getClassLoader().getResourceAsStream(resourcePath);
                    }

                    // 如果未找到，尝试系统类加载器
                    if (in == null) {
                        in = ClassLoader.getSystemResourceAsStream(resourcePath);
                    }

                    if (in == null) {
                        throw new Exception("Class resource not found");
                    }

                    ByteArrayOutputStream out = new ByteArrayOutputStream();
                    byte[] buffer = new byte[4096];
                    int bytesRead;
                    while ((bytesRead = in.read(buffer)) != -1) {
                        out.write(buffer, 0, bytesRead);
                    }
                    return out.toByteArray();
                } finally {
                    if (in != null) in.close();
                }
            }
        %>
        <%
            // 显示操作消息
            String message = (String) session.getAttribute("operationMessage");
            if (message != null) {
                out.write(message);
                session.removeAttribute("operationMessage");
            }

            out.write("<h2>Tomcat-Valve MemoryShell Scanner/Killer</h2>");
            String action = request.getParameter("action");
            String valveClassName = request.getParameter("valveClass");

            // 处理删除操作
            if ("kill".equals(action) && valveClassName != null) {
                try {
                    Valve basicValve = getBasicValve(request);
                    Valve[] valves = getValves(request);
                    boolean isEssential = false;
                    for (Valve v : valves) {
                        if (v.getClass().getName().equals(valveClassName) && isEssentialValve(v, basicValve)) {
                            isEssential = true;
                            break;
                        }
                    }
                    if (isEssential) {
                        session.setAttribute("operationMessage",
                                "<p style='color:red'>禁止删除核心Valve：" + valveClassName + "（系统必需组件）</p>");
                    } else {
                        deleteValve(request, valveClassName);
                        session.setAttribute("operationMessage",
                                "<p style='color:green'>Valve [" + valveClassName + "] 已删除</p>");
                    }
                    // 重定向到当前页面（不带参数）
                    response.sendRedirect(request.getRequestURI());
                    return;
                } catch (Exception e) {
                    session.setAttribute("operationMessage",
                            "<p style='color:red'>删除失败：" + e.getMessage() + "</p>");
                    response.sendRedirect(request.getRequestURI());
                    return;
                }
            }

            // 处理dump类文件操作
            if ("dump".equals(action) && valveClassName != null) {
                try {
                    // 参数有效性校验
                    if (valveClassName.trim().isEmpty()) {
                        throw new Exception("类名参数不能为空");
                    }

                    // 获取所有Valves找到匹配的实例
                    Valve[] valves = getValves(request);
                    Class<?> valveClass = null;
                    for (Valve valve : valves) {
                        if (valve.getClass().getName().equals(valveClassName)) {
                            valveClass = valve.getClass();
                            break;
                        }
                    }

                    if (valveClass == null) {
                        throw new Exception("未找到指定类：" + valveClassName);
                    }

                    // 获取类字节码
                    byte[] classBytes = getClassBytes(valveClass);
                    if (classBytes == null || classBytes.length == 0) {
                        throw new Exception("无法获取类字节码");
                    }

                    // 设置响应头
                    response.setContentType("application/octet-stream");
                    String filename = valveClass.getSimpleName() + ".class";
                    String encodedFilename = URLEncoder.encode(filename, "UTF-8").replaceAll("\\+", "%20");
                    response.setHeader("Content-Disposition",
                            "attachment; filename*=UTF-8''" + encodedFilename);

                    // 写入响应流
                    try (OutputStream outStream = response.getOutputStream()) {
                        outStream.write(classBytes);
                        outStream.flush();
                    }
                    return;

                } catch (Exception e) {
                    // 返回错误信息而不是空白页面
                    out.write("<script>alert('Dump失败：" + e.getMessage().replace("'", "\\'") + "');history.back();</script>");
                    return;
                }
            }

            // 展示Valve扫描结果
            out.write("<h4>Scan Result</h4>");
            out.write("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">");
            out.write("<thead><tr>");
            out.write("<th width=\"5%\">ID</th>");
            out.write("<th width=\"25%\">Valve类名</th>");
            out.write("<th width=\"10%\">类型</th>");
            out.write("<th width=\"15%\">类加载器</th>");
            out.write("<th width=\"35%\">类文件路径</th>");
            out.write("<th width=\"5%\">Dump</th>");
            out.write("<th width=\"5%\">Kill</th>");
            out.write("</tr></thead><tbody>");

            try {
                Pipeline pipeline = getPipeline(getStandardContext(request));
                Valve[] valves = pipeline.getValves();
                Valve basicValve = pipeline.getBasic();

                for (int i = 0; i < valves.length; i++) {
                    Valve valve = valves[i];
                    Class<?> valveClass = valve.getClass();
                    String className = valveClass.getName();
                    String valveType = (valve == basicValve) ? "基础Valve（核心）" : "普通Valve";
                    String classLoader = valveClass.getClassLoader() != null ?
                            valveClass.getClassLoader().getClass().getName() : "Bootstrap";
                    String filePath = classFileIsExists(valveClass);
                    boolean isEssential = isEssentialValve(valve, basicValve);

                    out.write("<tr>");
                    out.write("<td style=\"text-align:center\">" + (i + 1) + "</td>");
                    out.write("<td>" + className + "</td>");
                    out.write("<td>" + valveType + "</td>");
                    out.write("<td>" + classLoader + "</td>");
                    out.write("<td>" + filePath + "</td>");
                    out.write("<td style=\"text-align:center\"><a href=\"?action=dump&valveClass=" + className + "\">Dump</a></td>");

                    if (isEssential) {
                        out.write("<td style=\"text-align:center;color:gray\">禁止删除</td>");
                    } else {
                        out.write("<td style=\"text-align:center\"><a href=\"?action=kill&valveClass=" + className + "\">Kill</a></td>");
                    }
                    out.write("</tr>");
                }
            } catch (Exception e) {
                out.write("<tr><td colspan=\"7\" style=\"color:red\">扫描失败: " + e.toString() + "</td></tr>");
            }
            out.write("</tbody></table>");
        %>
    </div>
    <br/>
    c0ny1+ddg
</center>
</body>
</html>