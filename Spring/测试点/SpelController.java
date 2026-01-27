package org.example.springmaven_test.controller; //需要修改

import org.springframework.expression.Expression;
import org.springframework.expression.ExpressionParser;
import org.springframework.expression.spel.standard.SpelExpressionParser;
import org.springframework.expression.spel.support.StandardEvaluationContext;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/spel")
public class SpelController {

    private final ExpressionParser parser = new SpelExpressionParser();

    /**
     * application/x-www-form-urlencoded攻击载荷:
     * 1. 命令执行: expr=T(java.lang.Runtime).getRuntime().exec('whoami')、expr=T(java.lang.Runtime).getRuntime().exec("calc")
     * 2. 系统属性: expr=T(java.lang.System).getProperty('os.name')
     * 3. 类加载: expr=T(org.springframework.web.context.ContextLoader).getCurrentWebApplicationContext()
     * 4. 文件操作: expr=new java.io.File('/etc/passwd').exists()、expr=new ProcessBuilder("cmd","/c","calc").start()
     */
    @PostMapping(value = "/eval", consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    public ResponseEntity<Map<String, Object>> evaluateSpEL(@RequestParam("expr") String expr) {

        Map<String, Object> response = new HashMap<>();

        try {
            // 创建表达式上下文
            StandardEvaluationContext context = new StandardEvaluationContext();

            // 危险操作：直接解析和执行用户输入的SpEL表达式
            Expression expression = parser.parseExpression(expr);
            Object result = expression.getValue(context);

            // 处理结果
            response.put("success", true);
            response.put("expression", expr);

            if (result != null) {
                response.put("result", result.toString());
                response.put("resultType", result.getClass().getName());
            } else {
                response.put("result", "null");
                response.put("resultType", "null");
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            response.put("success", false);
            response.put("expression", expr);
            response.put("error", e.getMessage());
            response.put("errorType", e.getClass().getName());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
        }
    }

    /**
     * application/json攻击载荷:
     * {"expr":"T(java.lang.System).getProperty(\"os.name\")"}
     */
    @PostMapping(value = "/eval-json", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> evaluateSpELJson(@RequestBody SpelJsonRequest request) {

        String expr = request.getExpr();
        Map<String, Object> response = new HashMap<>();

        try {
            // 创建表达式上下文
            StandardEvaluationContext context = new StandardEvaluationContext();

            // 危险操作：直接解析和执行用户输入的SpEL表达式
            Expression expression = parser.parseExpression(expr);
            Object result = expression.getValue(context);

            // 处理结果
            response.put("success", true);
            response.put("expression", expr);

            if (result != null) {
                response.put("result", result.toString());
                response.put("resultType", result.getClass().getName());
            } else {
                response.put("result", "null");
                response.put("resultType", "null");
            }

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            response.put("success", false);
            response.put("expression", expr);
            response.put("error", e.getMessage());
            response.put("errorType", e.getClass().getName());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
        }
    }

    // 请求体封装类
    public static class SpelJsonRequest {
        private String expr;

        public String getExpr() {
            return expr;
        }

        public void setExpr(String expr) {
            this.expr = expr;
        }
    }
}
