package org.example.springmaven_test.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationContext;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.mvc.method.RequestMappingInfo;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;
import org.springframework.web.servlet.handler.BeanNameUrlHandlerMapping;
import org.springframework.web.servlet.handler.SimpleUrlHandlerMapping;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.*;

@Controller
@RequestMapping("/C")
public class MS_C_SKController {

    @Autowired
    private ApplicationContext applicationContext;

    /**
     * 全局变量：禁止卸载的包
     */
    private static final String[] ESSENTIAL_PACKAGES = {
            "org.springframework.", "org.apache."
    };

    /**
     * 全局变量：禁止卸载的控制器类
     */
    private static final String[] ESSENTIAL_CLASSES = {
            "ErrorController", "BasicErrorController",
            "org.example.springmaven_test.controller.MS_I_SKController"
    };

    /**
     * 项目入口重定向处理
     */
    @GetMapping("/")
    public String index() {return "forward:/MS_C_SK.html";}

    /**
     * 统一的控制器查杀入口 - 现在按方法卸载
     */
    @PostMapping("/kill")
    @ResponseBody
    public Map<String, Object> killController(
            @RequestParam String className,
            @RequestParam(required = false) String methodName,
            @RequestParam(required = false) String urlPattern) {

        Map<String, Object> result = new HashMap<>();

        if (isEssentialClass(className)) {
            result.put("success", false);
            result.put("message", "禁止删除系统关键组件: " + className);
            return result;
        }

        List<String> removalDetails = new ArrayList<>();
        boolean removed = false;

        try {
            // 1. 处理注解方式的控制器
            removed |= killAnnotationController(className, methodName, urlPattern, removalDetails);

            // 2. 处理SimpleUrlHandlerMapping配置的控制器
            removed |= killSimpleUrlController(className, urlPattern, removalDetails);

            // 3. 处理BeanNameUrlHandlerMapping配置的控制器
            removed |= killBeanNameUrlController(className, urlPattern, removalDetails);

            result.put("success", removed);
            result.put("message", removed ?
                    "成功删除控制器方法: " + className +
                            (methodName != null ? "." + methodName : "") +
                            (urlPattern != null ? " (URL: " + urlPattern + ")" : "") :
                    "未找到要删除的控制器方法");
            result.put("removalDetails", removalDetails);

        } catch (Exception e) {
            result.put("success", false);
            result.put("message", "删除过程中发生异常: " + e.getMessage());
        }

        return result;
    }

    /**
     * 方法1: 卸载注解方式的控制器 (RequestMappingHandlerMapping) - 按方法卸载
     */
    private boolean killAnnotationController(String className, String methodName, String urlPattern, List<String> removalDetails) {
        boolean removed = false;
        try {
            RequestMappingHandlerMapping mapping = applicationContext.getBean(RequestMappingHandlerMapping.class);
            Map<RequestMappingInfo, HandlerMethod> handlerMethods = mapping.getHandlerMethods();

            List<RequestMappingInfo> toRemove = new ArrayList<>();
            for (Map.Entry<RequestMappingInfo, HandlerMethod> entry : handlerMethods.entrySet()) {
                HandlerMethod handlerMethod = entry.getValue();

                // 检查类名是否匹配
                if (!handlerMethod.getBeanType().getName().equals(className)) {
                    continue;
                }

                // 如果指定了方法名，检查方法名是否匹配
                if (methodName != null && !handlerMethod.getMethod().getName().equals(methodName)) {
                    continue;
                }

                // 如果指定了URL模式，检查URL模式是否匹配
                if (urlPattern != null) {
                    Set<String> patterns = extractUrlPatterns(entry.getKey());
                    if (!patterns.contains(urlPattern)) {
                        continue;
                    }
                }

                toRemove.add(entry.getKey());
            }

            for (RequestMappingInfo info : toRemove) {
                mapping.unregisterMapping(info);
                removed = true;
                String detail = "注解方式(RequestMappingHandlerMapping)";
                if (methodName != null) {
                    detail += " - 方法: " + methodName;
                }
                if (urlPattern != null) {
                    detail += " - URL: " + urlPattern;
                }
                removalDetails.add(detail);
            }
        } catch (Exception e) {
            // 忽略异常，继续其他方式
        }
        return removed;
    }

    /**
     * 方法2: 卸载SimpleUrlHandlerMapping配置的控制器 - 按URL模式卸载
     */
    private boolean killSimpleUrlController(String className, String urlPattern, List<String> removalDetails) {
        boolean removed = false;
        try {
            Map<String, SimpleUrlHandlerMapping> urlMappings = applicationContext.getBeansOfType(SimpleUrlHandlerMapping.class);

            for (SimpleUrlHandlerMapping mapping : urlMappings.values()) {
                try {
                    // 尝试从urlMap字段移除
                    removed |= removeFromHandlerMapByUrl(mapping, "urlMap", className, urlPattern, removalDetails, "SimpleUrlHandlerMapping-urlMap");

                    // 尝试从handlerMap字段移除
                    removed |= removeFromHandlerMapByUrl(mapping, "handlerMap", className, urlPattern, removalDetails, "SimpleUrlHandlerMapping-handlerMap");

                } catch (Exception e) {
                    // 继续下一个SimpleUrlHandlerMapping
                }
            }
        } catch (Exception e) {
            // 忽略异常
        }
        return removed;
    }

    /**
     * 方法3: 卸载BeanNameUrlHandlerMapping配置的控制器 - 按URL模式卸载
     */
    private boolean killBeanNameUrlController(String className, String urlPattern, List<String> removalDetails) {
        boolean removed = false;
        try {
            Map<String, BeanNameUrlHandlerMapping> beanMappings = applicationContext.getBeansOfType(BeanNameUrlHandlerMapping.class);

            for (BeanNameUrlHandlerMapping mapping : beanMappings.values()) {
                try {
                    removed |= removeFromHandlerMapByUrl(mapping, "handlerMap", className, urlPattern, removalDetails, "BeanNameUrlHandlerMapping");
                } catch (Exception e) {
                    // 继续下一个BeanNameUrlHandlerMapping
                }
            }
        } catch (Exception e) {
            // 忽略异常
        }
        return removed;
    }

    /**
     * 通用的从映射字段按URL移除控制器的方法
     */
    private boolean removeFromHandlerMapByUrl(Object mapping, String fieldName, String className,
                                              String urlPattern, List<String> removalDetails, String handlerType) throws Exception {
        boolean removed = false;
        Object handlerMap = getFieldValue(mapping, fieldName);
        if (handlerMap instanceof Map) {
            Map<?, ?> map = (Map<?, ?>) handlerMap;
            List<Object> toRemoveKeys = new ArrayList<>();

            for (Map.Entry<?, ?> entry : map.entrySet()) {
                Object handler = entry.getValue();
                Object key = entry.getKey();

                // 检查类名是否匹配
                if (handler == null || !handler.getClass().getName().equals(className)) {
                    continue;
                }

                // 如果指定了URL模式，检查URL模式是否匹配
                if (urlPattern != null) {
                    if (key instanceof String) {
                        if (!key.equals(urlPattern)) {
                            continue;
                        }
                    } else if (key instanceof String[]) {
                        boolean found = false;
                        for (String pattern : (String[]) key) {
                            if (pattern.equals(urlPattern)) {
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            continue;
                        }
                    } else {
                        if (!key.toString().equals(urlPattern)) {
                            continue;
                        }
                    }
                }

                toRemoveKeys.add(key);
            }

            for (Object key : toRemoveKeys) {
                map.remove(key);
                removed = true;
                removalDetails.add(handlerType + " - URL: " + key);
            }
        }
        return removed;
    }

    /**
     * 统一的控制器扫描入口
     */
    @GetMapping("/scan")
    @ResponseBody
    public Map<String, Object> scanControllers() {
        Map<String, Object> result = new HashMap<>();
        List<Map<String, Object>> controllers = new ArrayList<>();

        try {
            // 1. 扫描注解方式的控制器
            scanAnnotationControllers(controllers);

            // 2. 扫描SimpleUrlHandlerMapping配置的控制器
            scanSimpleUrlControllers(controllers);

            // 3. 扫描BeanNameUrlHandlerMapping配置的控制器
            scanBeanNameUrlControllers(controllers);

            result.put("success", true);
            result.put("controllers", controllers);
            result.put("count", controllers.size());
            result.put("message", "扫描完成，找到 " + controllers.size() + " 个控制器方法");

        } catch (Exception e) {
            result.put("success", false);
            result.put("message", "扫描失败: " + e.getMessage());
            result.put("controllers", Collections.emptyList());
            result.put("count", 0);
        }

        return result;
    }

    /**
     * 扫描方法1: 注解方式的控制器 (RequestMappingHandlerMapping)
     */
    private void scanAnnotationControllers(List<Map<String, Object>> controllers) {
        try {
            RequestMappingHandlerMapping mapping = applicationContext.getBean(RequestMappingHandlerMapping.class);
            Map<RequestMappingInfo, HandlerMethod> handlerMethods = mapping.getHandlerMethods();

            for (Map.Entry<RequestMappingInfo, HandlerMethod> entry : handlerMethods.entrySet()) {
                try {
                    // 将每个URL模式拆分成单独的记录
                    Set<String> urlPatterns = extractUrlPatterns(entry.getKey());
                    for (String urlPattern : urlPatterns) {
                        Map<String, Object> info = createAnnotationHandlerInfo(entry.getKey(), entry.getValue(), urlPattern);
                        controllers.add(info);
                    }
                } catch (Exception e) {
                    // 静默处理异常
                }
            }
        } catch (Exception e) {
            // 忽略异常
        }
    }

    /**
     * 扫描方法2: SimpleUrlHandlerMapping配置的控制器
     */
    private void scanSimpleUrlControllers(List<Map<String, Object>> controllers) {
        try {
            Map<String, SimpleUrlHandlerMapping> urlMappings = applicationContext.getBeansOfType(SimpleUrlHandlerMapping.class);

            for (SimpleUrlHandlerMapping mapping : urlMappings.values()) {
                try {
                    // 扫描urlMap字段
                    scanHandlerMapField(mapping, "urlMap", controllers, "URL配置方式 (SimpleUrlHandlerMapping-urlMap)");

                    // 扫描handlerMap字段
                    scanHandlerMapField(mapping, "handlerMap", controllers, "URL配置方式 (SimpleUrlHandlerMapping-handlerMap)");

                } catch (Exception e) {
                    // 继续下一个SimpleUrlHandlerMapping
                }
            }
        } catch (Exception e) {
            // 忽略异常
        }
    }

    /**
     * 扫描方法3: BeanNameUrlHandlerMapping配置的控制器
     */
    private void scanBeanNameUrlControllers(List<Map<String, Object>> controllers) {
        try {
            Map<String, BeanNameUrlHandlerMapping> beanMappings = applicationContext.getBeansOfType(BeanNameUrlHandlerMapping.class);

            for (BeanNameUrlHandlerMapping mapping : beanMappings.values()) {
                try {
                    scanHandlerMapField(mapping, "handlerMap", controllers, "Bean名称方式 (BeanNameUrlHandlerMapping)");
                } catch (Exception e) {
                    // 继续下一个BeanNameUrlHandlerMapping
                }
            }
        } catch (Exception e) {
            // 忽略异常
        }
    }

    /**
     * 通用的扫描映射字段方法
     */
    private void scanHandlerMapField(Object mapping, String fieldName, List<Map<String, Object>> controllers, String handlerType) throws Exception {
        Object handlerMap = getFieldValue(mapping, fieldName);
        if (handlerMap instanceof Map) {
            Map<?, ?> map = (Map<?, ?>) handlerMap;

            for (Map.Entry<?, ?> entry : map.entrySet()) {
                try {
                    // 处理多个URL模式的情况
                    Object key = entry.getKey();
                    if (key instanceof String[]) {
                        for (String urlPattern : (String[]) key) {
                            Map<String, Object> info = createUrlHandlerInfo(urlPattern, entry.getValue(), handlerType);
                            controllers.add(info);
                        }
                    } else {
                        Map<String, Object> info = createUrlHandlerInfo(key.toString(), entry.getValue(), handlerType);
                        controllers.add(info);
                    }
                } catch (Exception e) {
                    // 静默处理单个entry的异常
                }
            }
        }
    }

    /**
     * 创建注解控制器信息 - 单个URL模式
     */
    private Map<String, Object> createAnnotationHandlerInfo(RequestMappingInfo mappingInfo, HandlerMethod handlerMethod, String urlPattern) {
        Class<?> controllerClass = handlerMethod.getBeanType();
        String className = controllerClass.getName();

        // HTTP方法
        Set<String> methods = new HashSet<>();
        if (mappingInfo.getMethodsCondition() != null) {
            mappingInfo.getMethodsCondition().getMethods().forEach(method -> methods.add(method.name()));
        }

        Map<String, Object> info = new HashMap<>();
        info.put("urlPatterns", Collections.singletonList(urlPattern));
        info.put("className", className);
        info.put("methodName", handlerMethod.getMethod().getName());
        info.put("httpMethods", new ArrayList<>(methods.isEmpty() ? Collections.singletonList("ANY") : methods));
        info.put("classLoader", getClassLoaderInfo(controllerClass));
        info.put("classLocation", getClassLocation(controllerClass));
        info.put("removable", !isEssentialClass(className));
        info.put("handlerType", "注解方式 (RequestMappingHandlerMapping)");

        return info;
    }

    /**
     * 创建URL映射控制器信息（通用方法）
     */
    private Map<String, Object> createUrlHandlerInfo(String urlPattern, Object handler, String handlerType) {
        Class<?> handlerClass = handler.getClass();
        String className = handlerClass.getName();

        Map<String, Object> info = new HashMap<>();
        info.put("urlPatterns", Collections.singletonList(urlPattern));
        info.put("className", className);
        info.put("methodName", "dynamic");
        info.put("httpMethods", Collections.singletonList("ANY"));
        info.put("classLoader", getClassLoaderInfo(handlerClass));
        info.put("classLocation", getClassLocation(handlerClass));
        info.put("removable", !isEssentialClass(className));
        info.put("handlerType", handlerType);

        return info;
    }

    private boolean isEssentialClass(String className) {
        if (className.equals(this.getClass().getName())) {
            return true;
        }

        for (String pkg : ESSENTIAL_PACKAGES) {
            if (className.startsWith(pkg)) return true;
        }

        for (String essentialClass : ESSENTIAL_CLASSES) {
            if (className.contains(essentialClass)) return true;
        }

        return false;
    }

    private Object getFieldValue(Object obj, String fieldName) throws Exception {
        Class<?> clazz = obj.getClass();
        while (clazz != null) {
            try {
                Field field = clazz.getDeclaredField(fieldName);
                field.setAccessible(true);
                return field.get(obj);
            } catch (NoSuchFieldException e) {
                clazz = clazz.getSuperclass();
            }
        }
        throw new NoSuchFieldException(fieldName);
    }

    @GetMapping("/dump")
    public ResponseEntity<Resource> dumpClass(@RequestParam String className) throws Exception {
        Class<?> clazz;
        try {
            clazz = Class.forName(className);
        } catch (ClassNotFoundException e) {
            Object bean = applicationContext.getBean(className);
            clazz = bean.getClass();
        }

        String resourcePath = clazz.getName().replace('.', '/') + ".class";
        InputStream in = clazz.getClassLoader().getResourceAsStream(resourcePath);

        if (in == null) {
            throw new RuntimeException("类文件不存在: " + resourcePath);
        }

        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] data = new byte[4096];
        int nRead;
        while ((nRead = in.read(data)) != -1) {
            buffer.write(data, 0, nRead);
        }

        byte[] classBytes = buffer.toByteArray();
        in.close();

        String filename = clazz.getSimpleName() + ".class";
        String encodedFilename = URLEncoder.encode(filename, StandardCharsets.UTF_8.name())
                .replace("+", "%20");

        ByteArrayResource resource = new ByteArrayResource(classBytes);

        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename*=UTF-8''" + encodedFilename)
                .body(resource);
    }

    private String getClassLoaderInfo(Class<?> clazz) {
        return clazz.getClassLoader() != null ? clazz.getClassLoader().getClass().getName() : "Bootstrap";
    }

    private String getClassLocation(Class<?> clazz) {
        try {
            String resourceName = clazz.getName().replace('.', '/') + ".class";
            URL url = clazz.getResource("/" + resourceName);

            if (url == null) {
                url = clazz.getClassLoader().getResource(resourceName);
            }

            if (url != null) {
                String path = url.toString();
                if (path.contains("!")) {
                    return "JAR: " + path.substring(0, path.indexOf('!'));
                }
                return path;
            }
            return "内存中（无法定位文件）";
        } catch (Exception e) {
            return "无法获取";
        }
    }

    /**
     * 提取URL模式的兼容方法
     */
    private Set<String> extractUrlPatterns(RequestMappingInfo mappingInfo) {
        Set<String> patterns = new HashSet<>();

        try {
            // 方式1: 新版本Spring (5.x+) - 标准API
            if (mappingInfo.getPatternsCondition() != null) {
                patterns.addAll(mappingInfo.getPatternsCondition().getPatterns());
            }
        } catch (Exception e) {
            // 忽略异常，尝试其他方式
        }

        // 如果标准API没获取到，尝试反射方式
        if (patterns.isEmpty()) {
            patterns.addAll(getUrlPatternsByReflection(mappingInfo));
        }

        return patterns;
    }

    /**
     * 通过反射多方式获取URL模式
     */
    @SuppressWarnings("unchecked")
    private Set<String> getUrlPatternsByReflection(RequestMappingInfo mappingInfo) {
        Set<String> patterns = new HashSet<>();

        // 尝试的反射字段名称
        String[] fieldNames = {"patterns", "pathPatternsCondition"};

        for (String fieldName : fieldNames) {
            if (!patterns.isEmpty()) break;

            try {
                Field field = mappingInfo.getClass().getDeclaredField(fieldName);
                field.setAccessible(true);
                Object fieldValue = field.get(mappingInfo);

                if (fieldValue == null) continue;

                if ("patterns".equals(fieldName) && fieldValue instanceof Set) {
                    // 直接模式集合
                    patterns.addAll((Set<String>) fieldValue);
                } else if ("pathPatternsCondition".equals(fieldName)) {
                    // 路径模式条件对象
                    Method getPatternsMethod = fieldValue.getClass().getMethod("getPatterns");
                    Object pathPatterns = getPatternsMethod.invoke(fieldValue);
                    if (pathPatterns instanceof Set) {
                        for (Object pattern : (Set<?>) pathPatterns) {
                            patterns.add(pattern.toString());
                        }
                    }
                }
            } catch (Exception e) {
                // 忽略反射异常
            }
        }

        return patterns;
    }
}