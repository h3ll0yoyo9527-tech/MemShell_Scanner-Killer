package org.example.springmaven_test.controller; //需要修改

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.io.File;
import java.nio.file.Files;
import java.nio.file.Paths;

@RestController
public class ClassLoaderController {

    @GetMapping("/loadClass")
    public String loadClass(String className) {
        try {
            // 1. 指定要加载的.class文件路径
            String classPath = "C:\\Users\\。\\Desktop\\BX\\Test\\" + className; //需要修改

            // 确保文件名以.class结尾
            if (!classPath.endsWith(".class")) {
                classPath += ".class";
            }

            // 2. 检查文件是否存在
            File file = new File(classPath);
            if (!file.exists()) {
                return "Error: Class file not found at " + classPath;
            }

            // 3. 读取.class文件字节码
            byte[] classBytes = Files.readAllBytes(Paths.get(classPath));

            // 4. 使用自定义ClassLoader
            CustomClassLoader customLoader = new CustomClassLoader(Thread.currentThread().getContextClassLoader());

            // 5. 从文件名提取类名（去掉.class后缀和路径）
            String simpleClassName = file.getName().replace(".class", "");
            Class<?> loadedClass = customLoader.defineClass(simpleClassName, classBytes);

            // 6. 实例化类
            Object instance = loadedClass.newInstance();

            return "Class loaded and instantiated successfully! Class: " + loadedClass.getName();

        } catch (Exception e) {
            e.printStackTrace();
            return "Error: " + e.getClass().getSimpleName() + ": " + e.getMessage();
        }
    }

    /**
     * 自定义ClassLoader，允许定义新类
     */
    private static class CustomClassLoader extends ClassLoader {
        public CustomClassLoader(ClassLoader parent) {
            super(parent);
        }

        public Class<?> defineClass(String name, byte[] classBytes) {
            // 使用protected的defineClass方法
            return defineClass(name, classBytes, 0, classBytes.length);
        }
    }
}
