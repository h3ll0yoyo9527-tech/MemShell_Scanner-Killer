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
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.handler.AbstractHandlerMapping;
import org.springframework.web.servlet.handler.MappedInterceptor;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.lang.reflect.Field;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.*;

@Controller
@RequestMapping("/I")
public class MS_I_SKController {

    @Autowired
    private ApplicationContext applicationContext;

    /**
     * 前端页面
     */
    @GetMapping("/")
    public String index() {
        return "forward:/MS_I_SK.html";
    }

    /**
     * 扫描Spring MVC拦截器
     */
    @GetMapping("/scan")
    @ResponseBody
    public Map<String, Object> scanInterceptors() {
        Map<String, Object> result = new HashMap<>();

        try {
            // 获取所有HandlerMapping
            Map<String, AbstractHandlerMapping> handlerMappings = applicationContext.getBeansOfType(AbstractHandlerMapping.class);

            List<Map<String, Object>> interceptors = new ArrayList<>();

            for (AbstractHandlerMapping handlerMapping : handlerMappings.values()) {
                // 通过反射获取适配器内的拦截器列表
                List<HandlerInterceptor> adaptedInterceptors = getAdaptedInterceptors(handlerMapping);

                for (HandlerInterceptor interceptor : adaptedInterceptors) {
                    Map<String, Object> interceptorInfo = analyzeInterceptor(interceptor, handlerMapping.getClass().getName());
                    if (interceptorInfo != null) {
                        interceptors.add(interceptorInfo);
                    }
                }
            }

            result.put("success", true);
            result.put("data", interceptors);

        } catch (Exception e) {
            result.put("success", false);
            result.put("message", e.getMessage());
        }

        return result;
    }

    /**
     * 删除可疑Interceptor
     */
    @PostMapping("/kill")
    @ResponseBody
    public Map<String, Object> killInterceptor(@RequestParam String className) {
        Map<String, Object> result = new HashMap<>();

        try {
            Map<String, AbstractHandlerMapping> handlerMappings = applicationContext.getBeansOfType(AbstractHandlerMapping.class);

            boolean found = false;
            int removedCount = 0;

            for (AbstractHandlerMapping handlerMapping : handlerMappings.values()) {
                List<HandlerInterceptor> adaptedInterceptors = getAdaptedInterceptors(handlerMapping);

                // 查找要删除的拦截器
                Iterator<HandlerInterceptor> iterator = adaptedInterceptors.iterator();
                while (iterator.hasNext()) {
                    HandlerInterceptor interceptor = iterator.next();
                    Class<?> interceptorClass = interceptor.getClass();

                    if (interceptorClass.getName().equals(className)) {
                        // 检查是否为系统关键组件
                        if (isEssentialInterceptor(interceptor)) {
                            result.put("success", false);
                            result.put("message", "禁止删除系统关键组件: " + className);
                            return result;
                        }

                        iterator.remove();
                        found = true;
                        removedCount++;

                        // 方案1：删除第一个匹配的拦截器后就返回
                        result.put("success", true);
                        result.put("message", "成功删除Interceptor: " + className);
                        return result;
                    }
                }
            }

            if (!found) {
                result.put("success", false);
                result.put("message", "未找到指定的Interceptor: " + className);
            }

        } catch (Exception e) {
            result.put("success", false);
            result.put("message", "删除失败: " + e.getMessage());
        }

        return result;
    }

    /**
     * Dump类文件
     */
    @GetMapping("/dump")
    public ResponseEntity<Resource> dumpClass(@RequestParam String className) {
        try {
            Class<?> clazz;
            try {
                clazz = Class.forName(className);
            } catch (ClassNotFoundException e) {
                // 尝试通过应用上下文查找
                Object bean = applicationContext.getBean(className);
                clazz = bean.getClass();
            }

            String resourcePath = clazz.getName().replace('.', '/') + ".class";
            ClassLoader classLoader = clazz.getClassLoader();

            if (classLoader == null) {
                throw new RuntimeException("Bootstrap类加载器的类无法dump");
            }

            InputStream in = classLoader.getResourceAsStream(resourcePath);
            if (in == null) {
                throw new RuntimeException("类文件不存在: " + resourcePath);
            }

            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            int nRead;
            byte[] data = new byte[4096];
            while ((nRead = in.read(data, 0, data.length)) != -1) {
                buffer.write(data, 0, nRead);
            }

            byte[] classBytes = buffer.toByteArray();
            in.close();

            String filename = clazz.getSimpleName() + ".class";
            String encodedFilename = URLEncoder.encode(filename, StandardCharsets.UTF_8.toString())
                    .replaceAll("\\+", "%20");

            ByteArrayResource resource = new ByteArrayResource(classBytes);

            return ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .header(HttpHeaders.CONTENT_DISPOSITION,
                            "attachment; filename*=UTF-8''" + encodedFilename)
                    .body(resource);

        } catch (Exception e) {
            throw new RuntimeException("Dump失败: " + e.getMessage(), e);
        }
    }

    /**
     * 通过反射获取HandlerMapping中的拦截器列表
     */
    @SuppressWarnings("unchecked")
    private List<HandlerInterceptor> getAdaptedInterceptors(AbstractHandlerMapping handlerMapping) {
        try {
            Field adaptedInterceptorsField = AbstractHandlerMapping.class.getDeclaredField("adaptedInterceptors");
            adaptedInterceptorsField.setAccessible(true);
            return (List<HandlerInterceptor>) adaptedInterceptorsField.get(handlerMapping);
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    /**
     * 分析Interceptor信息
     */
    private Map<String, Object> analyzeInterceptor(HandlerInterceptor interceptor, String handlerMappingName) {
        Map<String, Object> info = new HashMap<>();

        Class<?> interceptorClass = interceptor.getClass();

        // 拦截路径
        Set<String> pathPatterns = new HashSet<>();

        try {
            // 如果是MappedInterceptor，获取路径模式
            if (interceptor instanceof MappedInterceptor) {
                MappedInterceptor mappedInterceptor = (MappedInterceptor) interceptor;

                // 获取路径模式
                if (mappedInterceptor.getPathPatterns() != null) {
                    String[] patterns = mappedInterceptor.getPathPatterns();
                    if (patterns != null) {
                        pathPatterns.addAll(Arrays.asList(patterns));
                    }
                }
            }
        } catch (Exception e) {
            pathPatterns.add("无法获取路径模式");
        }

        if (pathPatterns.isEmpty()) {
            pathPatterns.add("/* (全局拦截)");
        }

        // 类加载器信息
        String classLoader = interceptorClass.getClassLoader() != null ?
                interceptorClass.getClassLoader().getClass().getName() : "Bootstrap";

        // 类文件位置
        String classLocation = getClassLocation(interceptorClass);

        // 是否可删除
        boolean removable = !isEssentialInterceptor(interceptor);

        info.put("className", interceptorClass.getName());
        info.put("pathPatterns", new ArrayList<>(pathPatterns));
        info.put("classLoader", classLoader);
        info.put("classLocation", classLocation);
        info.put("removable", removable);

        return info;
    }

    /**
     * 获取类文件位置
     */
    private String getClassLocation(Class<?> clazz) {
        try {
            String className = clazz.getName().replace('.', '/') + ".class";
            URL url = clazz.getResource("/" + className);

            if (url == null) {
                ClassLoader classLoader = clazz.getClassLoader();
                if (classLoader == null) {
                    return "Bootstrap类加载器";
                }
                url = classLoader.getResource(className);
            }

            if (url == null) {
                return "内存中（无磁盘文件）";
            } else if (url.getProtocol().equals("jar")) {
                return "JAR包: " + url.getPath();
            } else {
                return "磁盘路径: " + url.getPath();
            }
        } catch (Exception e) {
            return "无法获取";
        }
    }

    /**
     * 检查是否为系统关键组件
     */
    private boolean isEssentialInterceptor(HandlerInterceptor interceptor) {
        Class<?> interceptorClass = interceptor.getClass();
        String className = interceptorClass.getName();

        // 更精确的系统关键组件判断
        return isSpringCoreInterceptor(className) ||
                isSpringSecurityInterceptor(className) ||
                className.contains("ResourceUrlProvider") ||
                interceptorClass == this.getClass();
    }

    /**
     * 判断是否为Spring核心拦截器（不可删除）
     */
    private boolean isSpringCoreInterceptor(String className) {
        // 只保护真正核心的Spring拦截器
        String[] essentialSpringInterceptors = {
                "org.springframework.web.servlet.i18n.LocaleChangeInterceptor",
                "org.springframework.web.servlet.theme.ThemeChangeInterceptor",
                "org.springframework.web.servlet.handler.ConversionServiceExposingInterceptor",
                "org.springframework.web.servlet.handler.WebRequestHandlerInterceptorAdapter",
                "org.springframework.web.servlet.mvc.WebContentInterceptor"
        };

        for (String essential : essentialSpringInterceptors) {
            if (essential.equals(className)) {
                return true;
            }
        }

        return false;
    }

    /**
     * 判断是否为Spring Security相关拦截器
     */
    private boolean isSpringSecurityInterceptor(String className) {
        return className.startsWith("org.springframework.security.") ||
                className.contains("SecurityInterceptor");
    }
}