allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Fallback for older plugins like file_picker that crash without compileSdk
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val androidExt = extensions.findByName("android") as? com.android.build.gradle.LibraryExtension
            if (androidExt != null && androidExt.compileSdk == null) {
                androidExt.compileSdk = 35
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
