allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Ép mọi module plugin (app_settings/device_info_plus/share_plus… vốn compile ở
// android-33) dùng compileSdk 36 — androidx fragment/window/activity mới yêu cầu
// >=34. Đăng ký afterEvaluate TRƯỚC evaluationDependsOn (nếu không sẽ "already
// evaluated"). Reflection để không phụ thuộc kiểu AGP ở buildscript gốc.
subprojects {
    afterEvaluate {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(android, 36)
            } catch (_: Exception) {
            }
        }
    }
}
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                androidExtension.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
