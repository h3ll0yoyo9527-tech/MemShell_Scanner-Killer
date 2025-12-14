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
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Tomcat-Filter MemoryShell Scanner/Killer</title>
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

            // 获取所有Filter配置
            public HashMap<String, Object> getFilterConfigs(HttpServletRequest request) throws Exception {
                Object standardContext = getStandardContext(request);
                Field filterConfigsField = standardContext.getClass().getDeclaredField("filterConfigs");
                filterConfigsField.setAccessible(true);
                return (HashMap<String, Object>) filterConfigsField.get(standardContext);
            }

            // 获取Filter映射
            public Object[] getFilterMaps(HttpServletRequest request) throws Exception {
                Object standardContext = getStandardContext(request);
                Field filterMapsField = standardContext.getClass().getDeclaredField("filterMaps");
                filterMapsField.setAccessible(true);
                Object filterMaps = filterMapsField.get(standardContext);

                // 处理不同Tomcat版本的差异
                try {
                    Field arrayField = filterMaps.getClass().getDeclaredField("array");
                    arrayField.setAccessible(true);
                    return (Object[]) arrayField.get(filterMaps);
                } catch (Exception e) {
                    return (Object[]) filterMaps;
                }
            }

            // 删除指定Filter
            public synchronized void deleteFilter(HttpServletRequest request, String filterName) throws Exception {
                Object standardContext = getStandardContext(request);
                HashMap<String, Object> filterConfigs = getFilterConfigs(request);
                Object appFilterConfig = filterConfigs.get(filterName);

                if (appFilterConfig != null) {
                    // 获取FilterDef
                    Field filterDefField = appFilterConfig.getClass().getDeclaredField("filterDef");
                    filterDefField.setAccessible(true);
                    Object filterDef = filterDefField.get(appFilterConfig);

                    // 调用removeFilterDef方法
                    Class<?> filterDefClass = Class.forName("org.apache.tomcat.util.descriptor.web.FilterDef");
                    Method removeFilterDef = standardContext.getClass().getDeclaredMethod("removeFilterDef", filterDefClass);
                    removeFilterDef.setAccessible(true);
                    removeFilterDef.invoke(standardContext, filterDef);

                    // 删除Filter映射
                    Object[] filterMaps = getFilterMaps(request);
                    Class<?> filterMapClass = Class.forName("org.apache.tomcat.util.descriptor.web.FilterMap");
                    for (Object filterMap : filterMaps) {
                        Field filterNameField = filterMap.getClass().getDeclaredField("filterName");
                        filterNameField.setAccessible(true);
                        String name = (String) filterNameField.get(filterMap);

                        if (filterName.equals(name)) {
                            Method removeFilterMap = standardContext.getClass().getDeclaredMethod("removeFilterMap", filterMapClass);
                            removeFilterMap.setAccessible(true);
                            removeFilterMap.invoke(standardContext, filterMap);
                        }
                    }
                }
            }

            // 获取Filter名称
            public String getFilterName(Object filterMap) throws Exception {
                Method getFilterName = filterMap.getClass().getDeclaredMethod("getFilterName");
                getFilterName.setAccessible(true);
                return (String) getFilterName.invoke(filterMap);
            }

            // 获取URL模式
            public String[] getURLPatterns(Object filterMap) throws Exception {
                Method getURLPatterns = filterMap.getClass().getDeclaredMethod("getURLPatterns");
                getURLPatterns.setAccessible(true);
                return (String[]) getURLPatterns.invoke(filterMap);
            }

            // 检查是否为Tomcat核心Filter
            public boolean isCoreFilter(Class<?> filterClass) {
                String className = filterClass.getName();
                return className.startsWith("org.apache.catalina.core.") ||
                        className.startsWith("org.apache.catalina.filters.");
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
            String message = (String) session.getAttribute("operationMessage");
            if (message != null) {
                out.write(message);
                session.removeAttribute("operationMessage");
            }

            out.write("<h2>Tomcat-Filter MemoryShell Scanner/Killer</h2>");
            String action = request.getParameter("action");
            String filterName = request.getParameter("filterName");

            // 处理删除操作
            if ("kill".equals(action) && filterName != null) {
                try {
                    HashMap<String, Object> filterConfigs = getFilterConfigs(request);
                    Object appFilterConfig = filterConfigs.get(filterName);
                    if (appFilterConfig == null) {
                        throw new Exception("Filter not found: " + filterName);
                    }

                    Field filterField = appFilterConfig.getClass().getDeclaredField("filter");
                    filterField.setAccessible(true);
                    Object filter = filterField.get(appFilterConfig);

                    if (isCoreFilter(filter.getClass())) {
                        session.setAttribute("operationMessage",
                                "<p style='color:red'>禁止删除核心Filter：" + filterName + "（系统必需组件）</p>");
                    } else {
                        deleteFilter(request, filterName);
                        session.setAttribute("operationMessage",
                                "<p style='color:green'>Filter [" + filterName + "] 已删除</p>");
                    }
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
            if ("dump".equals(action) && filterName != null) {
                try {
                    HashMap<String, Object> filterConfigs = getFilterConfigs(request);
                    Object appFilterConfig = filterConfigs.get(filterName);
                    if (appFilterConfig == null) {
                        throw new Exception("Filter not found: " + filterName);
                    }

                    Field filterField = appFilterConfig.getClass().getDeclaredField("filter");
                    filterField.setAccessible(true);
                    Object filter = filterField.get(appFilterConfig);
                    Class<?> filterClass = filter.getClass();

                    // 获取类字节码
                    byte[] classBytes = getClassBytes(filterClass);

                    // 设置响应头
                    response.setContentType("application/octet-stream");
                    String filename = filterClass.getSimpleName() + ".class";
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

            // 展示Filter扫描结果
            out.write("<h4>Scan Result</h4>");
            out.write("<table border=\"1\" cellspacing=\"0\" width=\"95%\" style=\"table-layout:fixed;word-break:break-all;background:#f2f2f2\">");
            out.write("<thead><tr>");
            out.write("<th width=\"5%\">ID</th>");
            out.write("<th width=\"15%\">Filter名称</th>");
            out.write("<th width=\"5%\">URL模式</th>");
            out.write("<th width=\"25%\">Filter类名</th>");
            out.write("<th width=\"15%\">类加载器</th>");
            out.write("<th width=\"25%\">类文件路径</th>");
            out.write("<th width=\"5%\">Dump</th>");
            out.write("<th width=\"5%\">Kill</th>");
            out.write("</tr></thead><tbody>");

            try {
                HashMap<String, Object> filterConfigs = getFilterConfigs(request);
                Object[] filterMaps = getFilterMaps(request);

                for (int i = 0; i < filterMaps.length; i++) {
                    Object filterMap = filterMaps[i];
                    String name = getFilterName(filterMap);
                    Object appFilterConfig = filterConfigs.get(name);

                    if (appFilterConfig != null) {
                        Field filterField = appFilterConfig.getClass().getDeclaredField("filter");
                        filterField.setAccessible(true);
                        Object filter = filterField.get(appFilterConfig);
                        Class<?> filterClass = filter.getClass();
                        String[] urlPatterns = getURLPatterns(filterMap);
                        String patterns = String.join(", ", urlPatterns);

                        String classLoader = filterClass.getClassLoader() != null ?
                                filterClass.getClassLoader().getClass().getName() : "Bootstrap";
                        String filePath = classFileIsExists(filterClass);
                        boolean isCore = isCoreFilter(filterClass);

                        out.write("<tr>");
                        out.write("<td style=\"text-align:center\">" + (i + 1) + "</td>");
                        out.write("<td>" + name + "</td>");
                        out.write("<td>" + patterns + "</td>");
                        out.write("<td>" + filterClass.getName() + "</td>");
                        out.write("<td>" + classLoader + "</td>");
                        out.write("<td>" + filePath + "</td>");
                        out.write("<td style=\"text-align:center\"><a href=\"?action=dump&filterName=" + name + "\">Dump</a></td>");

                        if (isCore) {
                            out.write("<td style=\"text-align:center;color:gray\">禁止删除</td>");
                        } else {
                            out.write("<td style=\"text-align:center\"><a href=\"?action=kill&filterName=" + name + "\">Kill</a></td>");
                        }
                        out.write("</tr>");
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