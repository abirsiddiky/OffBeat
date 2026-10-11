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
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureNamespace = {
        val extension = extensions.findByName("android")
        if (extension != null) {
            val getNamespaceMethod = extension.javaClass.methods.find { it.name == "getNamespace" }
            val setNamespaceMethod = extension.javaClass.methods.find { it.name == "setNamespace" && it.parameterTypes.size == 1 }
            if (getNamespaceMethod != null && setNamespaceMethod != null) {
                val currentNamespace = getNamespaceMethod.invoke(extension) as? String
                if (currentNamespace.isNullOrEmpty()) {
                    val fallbackNamespace = if (name == "on_audio_query_android") {
                        "com.lucasjosino.on_audio_query"
                    } else {
                        "com.example.${name.replace('-', '_')}"
                    }
                    setNamespaceMethod.invoke(extension, fallbackNamespace)
                }
            }

            if (name == "on_audio_query_android") {
                val compileMethod = extension.javaClass.methods.find {
                    (it.name == "compileSdkVersion" || it.name == "setCompileSdkVersion" || it.name == "setCompileSdk") &&
                    it.parameterTypes.size == 1 &&
                    (it.parameterTypes[0] == java.lang.Integer.TYPE || it.parameterTypes[0] == Integer::class.java)
                }
                compileMethod?.invoke(extension, 35)
            }
        }
    }
    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate {
            configureNamespace()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
