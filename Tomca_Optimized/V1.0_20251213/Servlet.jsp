<%@ page import="java.net.URL" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.lang.reflect.Method" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="java.util.Map" %>
<%@ page import="org.apache.catalina.Wrapper" %>
<%@ page import="java.io.InputStream" %>
<%@ page import="java.io.ByteArrayOutputStream" %>
<%@ page import="java.io.OutputStream" %>
<%@ page import="javax.servlet.http.HttpSession" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Tomcat-Servlet MemoryShell Scanner/Killer</title>
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

            // 获取所有Servlet子容器
            public Map<String, Object> getChildren(HttpServletRequest request) throws Exception {
                Object standardContext = getStandardContext(request);
                Field childrenField = standardContext.getClass().getSuperclass().getDeclaredField("children");
                childrenField.setAccessible(true);
                return (Map<String, Object>) childrenField.get(standardContext);
            }

            // 获取Servlet映射
            public Map<String, String> getServletMappings(HttpServletRequest request) throws Exception {
                Object standardContext = getStandardContext(request);
                Field servletMappingsField = standardContext.getClass().getDeclaredField("servletMappings");
                servletMappingsField.setAccessible(true);
                return (Map<String, String>) servletMappingsField.get(standardContext);
            }

            // 删除指定Servlet
            public synchronized void deleteServlet(HttpServletRequest request, String servletName) throws Exception {
                Object standardContext = getStandardContext(request);
                Map<String, Object> children = getChildren(request);
                Map<String, String> servletMappings = getServletMappings(request);

                // 查找并删除Servlet映射
                String urlPattern = null;
                for (Map.Entry<String, String> entry : servletMappings.entrySet()) {
                    if (entry.getValue().equals(servletName)) {
                        urlPattern = entry.getKey();
                        break;
                    }
                }

                if (urlPattern != null) {
                    // 删除Servlet映射
                    Method removeServletMapping = standardContext.getClass().getDeclaredMethod("removeServletMapping", String.class);
                    removeServletMapping.setAccessible(true);
                    removeServletMapping.invoke(standardContext, urlPattern);

                    // 删除子容器
                    Object wrapper = children.get(servletName);
                    if (wrapper != null) {
                        Method removeChild = standardContext.getClass().getDeclaredMethod("removeChild", org.apache.catalina.Container.class);
                        removeChild.setAccessible(true);
                        removeChild.invoke(standardContext, wrapper);
                    }
                }
            }

            // 检查是否为Tomcat核心Servlet
            public boolean isCoreServlet(Class<?> servletClass) {
                if (servletClass == null) return false;
                String className = servletClass.getName();
                return className.startsWith("org.apache.catalina.servlets.") ||
                        className.startsWith("org.apache.jasper.servlet.");
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
                InputStream in = clazz.getClassLoader().getResourceAsStream(resourcePath);
                if (in == null) {
                    throw new Exception("Class resource not found");
                }

                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buffer = new byte[4096];
                int bytesRead;
                while ((bytesRead = in.read(buffer)) != -1) {
                    out.write(buffer, 0, bytesRead);
                }
                in.close();
                return out.toByteArray();
            }
        %>
        <%
            // 显示操作消息
            HttpSession httpSession = request.getSession(false);
            String message = httpSession != null ? (String) httpSession.getAttribute("operationMessage") : null;
            if (message != null) {
                out.write(message);
                httpSession.removeAttribute("operationMessage");
            }

            out.write("<h2>Tomcat-Servlet MemoryShell Scanner/Killer</h2>");
            String action = request.getParameter("action");
            String servletName = request.getParameter("servletName");

            // 处理删除操作
            if ("kill".equals(action) && servletName != null) {
                try {
                    Map<String, Object> children = getChildren(request);
                    Object wrapper = children.get(servletName);

                    if (wrapper == null) {
                        throw new Exception("Servlet not found: " + servletName);
                    }

                    // 获取Servlet类
                    Wrapper servletWrapper = (Wrapper) wrapper;
                    Class<?> servletClass = null;
                    try {
                        servletClass = Class.forName(servletWrapper.getServletClass());
                    } catch (Exception e) {
                        Object servletInstance = servletWrapper.getServlet();
                        if (servletInstance != null) {
                            servletClass = servletInstance.getClass();
                        }
                    }

                    if (servletClass != null && isCoreServlet(servletClass)) {
                        if (httpSession != null) {
                            httpSession.setAttribute("operationMessage",
                                    "<p style='color:red'>禁止删除核心Servlet：" + servletName + "（系统必需组件）</p>");
                        }
                    } else {
                        deleteServlet(request, servletName);
                        if (httpSession != null) {
                            httpSession.setAttribute("operationMessage",
                                    "<p style='color:green'>Servlet [" + servletName + "] 已删除</p>");
                        }
                    }
                    response.sendRedirect(request.getRequestURI());
                    return;
                } catch (Exception e) {
                    if (httpSession != null) {
                        httpSession.setAttribute("operationMessage",
                                "<p style='color:red'>删除失败：" + e.getMessage() + "</p>");
                    }
                    response.sendRedirect(request.getRequestURI());
                    return;
                }
            }

            // 处理dump类文件操作
            if ("dump".equals(action) && servletName != null) {
                try {
                    Map<String, Object> children = getChildren(request);
                    Object wrapper = children.get(servletName);

                    if (wrapper == null) {
                        throw new Exception("Servlet not found: " + servletName);
                    }

                    // 获取Servlet类
                    Wrapper servletWrapper = (Wrapper) wrapper;
                    Class<?> servletClass = null;
                    try {
                        servletClass = Class.forName(servletWrapper.getServletClass());
                    } catch (Exception e) {
                        Object servletInstance = servletWrapper.getServlet();
                        if (servletInstance != null) {
                            servletClass = servletInstance.getClass();
                        }
                    }

                    if (servletClass == null) {
                        throw new Exception("无法获取Servlet类");
                    }

                    // 获取类字节码
                    byte[] classBytes = getClassBytes(servletClass);

                    // 设置响应头
                    response.setContentType("application/octet-stream");
                    String filename = servletClass.getSimpleName() + ".class";
                    String encodedFilename = URLEncoder.encode(filename, "UTF-8").replaceAll("\\+", "%20");
                    response.setHeader("Content-Disposition",
                            "attachment; filename*=UTF-8''" + encodedFilename);

                    // 写入响应流
                    OutputStream outStream = response.getOutputStream();
                    outStream.write(classBytes);
                    outStream.flush();
                    outStream.close();
                    return;
                } catch (Exception e) {
                    out.write("<script>alert('Dump失败：" + e.getMessage().replace("'", "\\'") + "');history.back();</script>");
                    return;
                }
            }

            // 展示Servlet扫描结果
            out.write("<h4>Scan Result</h4>");
            out.write("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">");
            out.write("<thead><tr>");
            out.write("<th width=\"5%\">ID</th>");
            out.write("<th width=\"15%\">Servlet名称</th>");
            out.write("<th width=\"5%\">URL模式</th>");
            out.write("<th width=\"25%\">Servlet类名</th>");
            out.write("<th width=\"15%\">类加载器</th>");
            out.write("<th width=\"25%\">类文件路径</th>");
            out.write("<th width=\"5%\">Dump</th>");
            out.write("<th width=\"5%\">Kill</th>");
            out.write("</tr></thead><tbody>");

            try {
                Map<String, Object> children = getChildren(request);
                Map<String, String> servletMappings = getServletMappings(request);
                int servletId = 0;

                for (Map.Entry<String, String> mapping : servletMappings.entrySet()) {
                    String urlPattern = mapping.getKey();
                    String name = mapping.getValue();
                    Object wrapper = children.get(name);

                    if (wrapper != null && wrapper instanceof Wrapper) {
                        Wrapper servletWrapper = (Wrapper) wrapper;
                        Class<?> servletClass = null;
                        try {
                            servletClass = Class.forName(servletWrapper.getServletClass());
                        } catch (Exception e) {
                            Object servletInstance = servletWrapper.getServlet();
                            if (servletInstance != null) {
                                servletClass = servletInstance.getClass();
                            }
                        }

                        if (servletClass != null) {
                            String className = servletClass.getName();
                            String classLoader = servletClass.getClassLoader() != null ?
                                    servletClass.getClassLoader().getClass().getName() : "Bootstrap";
                            String filePath = classFileIsExists(servletClass);
                            boolean isCore = isCoreServlet(servletClass);

                            out.write("<tr>");
                            out.write("<td style=\"text-align:center\">" + (++servletId) + "</td>");
                            out.write("<td>" + name + "</td>");
                            out.write("<td>" + urlPattern + "</td>");
                            out.write("<td>" + className + "</td>");
                            out.write("<td>" + classLoader + "</td>");
                            out.write("<td>" + filePath + "</td>");
                            out.write("<td style=\"text-align:center\"><a href=\"?action=dump&servletName=" + name + "\">Dump</a></td>");

                            if (isCore) {
                                out.write("<td style=\"text-align:center;color:gray\">禁止删除</td>");
                            } else {
                                out.write("<td style=\"text-align:center\"><a href=\"?action=kill&servletName=" + name + "\">Kill</a></td>");
                            }
                            out.write("</tr>");
                        }
                    }
                }
            } catch (Exception e) {
                out.write("<tr><td colspan=\"8\" style=\"color:red\">扫描失败: " + e.toString() + "</td></tr>");
            }
            out.write("</tbody></table>");
        %>
    </div>
    <br/>
    c0ny1+ddg
</center>
</body>
</html>