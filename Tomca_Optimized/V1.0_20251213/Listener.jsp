<%@ page import="java.net.URL" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.util.concurrent.CopyOnWriteArrayList" %>
<%@ page import="java.net.URLEncoder" %>
<%@ page import="java.io.ByteArrayOutputStream" %>
<%@ page import="java.io.OutputStream" %>
<%@ page import="java.io.InputStream" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Tomcat-Listener MemoryShell Scanner/Killer</title>
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

            // 获取监听器列表
            public synchronized CopyOnWriteArrayList<Object> getListenerList(HttpServletRequest request) throws Exception {
                Object standardContext = getStandardContext(request);
                Field listenersField = standardContext.getClass().getDeclaredField("applicationEventListenersList");
                listenersField.setAccessible(true);
                return (CopyOnWriteArrayList<Object>) listenersField.get(standardContext);
            }

            // 删除指定索引的监听器
            public synchronized void deleteListener(HttpServletRequest request, int index) throws Exception {
                CopyOnWriteArrayList<Object> listeners = getListenerList(request);
                if (index >= 0 && index < listeners.size()) {
                    listeners.remove(index);
                }
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

            // 检测是否为核心组件
            public boolean isCoreListener(Class<?> clazz) {
                if (clazz == null) return false;
                String className = clazz.getName();
                return className.startsWith("org.apache.catalina.") ||
                        className.startsWith("org.apache.tomcat.") ||
                        className.startsWith("org.apache.coyote.");
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

            out.write("<h2>Tomcat-Listener MemoryShell Scanner/Killer</h2>");
            String action = request.getParameter("action");
            String className = request.getParameter("className");
            String indexParam = request.getParameter("index");

            // 处理删除操作
            if ("kill".equals(action) && indexParam != null) {
                try {
                    int index = Integer.parseInt(indexParam);
                    CopyOnWriteArrayList<Object> listeners = getListenerList(request);

                    if (index < 0 || index >= listeners.size()) {
                        throw new Exception("无效的监听器索引");
                    }

                    Object listener = listeners.get(index);
                    Class<?> listenerClass = listener.getClass();

                    if (isCoreListener(listenerClass)) {
                        if (httpSession != null) {
                            httpSession.setAttribute("operationMessage",
                                    "<p style='color:red'>禁止删除核心监听器：" + listenerClass.getName() + "（系统必需组件）</p>");
                        }
                    } else {
                        deleteListener(request, index);
                        if (httpSession != null) {
                            httpSession.setAttribute("operationMessage",
                                    "<p style='color:green'>监听器删除成功！</p>");
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

            // 处理dump操作
            if ("dump".equals(action) && className != null) {
                try {
                    Class<?> clazz = Class.forName(className);
                    byte[] classBytes = getClassBytes(clazz);

                    response.setContentType("application/octet-stream");
                    String filename = clazz.getSimpleName() + ".class";
                    String encodedFilename = URLEncoder.encode(filename, "UTF-8").replaceAll("\\+", "%20");
                    response.setHeader("Content-Disposition",
                            "attachment; filename*=UTF-8''" + encodedFilename);

                    OutputStream outStream = response.getOutputStream();
                    outStream.write(classBytes);
                    outStream.flush();
                    outStream.close();
                    return;
                } catch (Exception e) {
                    if (httpSession != null) {
                        httpSession.setAttribute("operationMessage",
                                "<p style='color:red'>Dump失败：" + e.getMessage() + "</p>");
                    }
                    response.sendRedirect(request.getRequestURI());
                    return;
                }
            }

            // 扫描并展示监听器
            out.write("<h4>Scan Result</h4>");
            out.write("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">");
            out.write("<thead><tr>");
            out.write("<th width=\"5%\">ID</th>");
            out.write("<th width=\"20%\">Listener类名</th>");
            out.write("<th width=\"25%\">类加载器</th>");
            out.write("<th width=\"40%\">类文件路径</th>");
            out.write("<th width=\"5%\">Dump</th>");
            out.write("<th width=\"5%\">Kill</th>");
            out.write("</tr></thead><tbody>");

            try {
                CopyOnWriteArrayList<Object> listeners = getListenerList(request);
                if (listeners == null || listeners.size() == 0) {
                    out.write("<tr><td colspan='6' style='text-align:center'>未发现任何监听器</td></tr>");
                } else {
                    for (int i = 0; i < listeners.size(); i++) {
                        Object listener = listeners.get(i);
                        Class<?> listenerClass = listener.getClass();
                        String classLoaderName = (listenerClass.getClassLoader() != null) ?
                                listenerClass.getClassLoader().getClass().getName() : "Bootstrap";
                        boolean isCore = isCoreListener(listenerClass);
                        String rowStyle = isCore ? "system-component" : "memshell-suspect";

                        out.write("<tr class=\"" + rowStyle + "\">");
                        out.write(String.format("<td style=\"text-align:center\">%d</td>", i + 1));
                        out.write(String.format("<td>%s</td>", listenerClass.getName()));
                        out.write(String.format("<td>%s</td>", classLoaderName));
                        out.write(String.format("<td>%s</td>", classFileIsExists(listenerClass)));
                        out.write(String.format("<td style=\"text-align:center\"><a href=\"?action=dump&className=%s\">Dump</a></td>",
                                URLEncoder.encode(listenerClass.getName(), "UTF-8")));

                        if (isCore) {
                            out.write("<td style=\"text-align:center;color:gray\">系统组件</td>");
                        } else {
                            out.write(String.format("<td style=\"text-align:center\"><a href=\"?action=kill&index=%d\">Kill</a></td>", i));
                        }
                        out.write("</tr>");
                    }
                }
            } catch (Exception e) {
                out.write("<tr><td colspan=\"6\" style=\"color:red\">扫描失败: " + e.toString() + "</td></tr>");
            }
            out.write("</tbody></table>");
        %>
    </div>
    <br/>
    c0ny1+ddg
</center>
</body>
</html>