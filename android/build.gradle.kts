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

// Configure global Java/Kotlin compatibility and suppress obsolete-options warning
subprojects {
    // Apply to JavaCompile tasks (all modules/plugins)
    tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
        // Ensure source/target compatibility are set to Java 11
        sourceCompatibility = "11"
        targetCompatibility = "11"
        // Suppress the obsolete-options lint warning
        options.compilerArgs.add("-Xlint:-options")
    }

    // Apply to Kotlin compile tasks (if Kotlin plugin is used)
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
        kotlinOptions {
            jvmTarget = "11"
            // Optional: enable explicit API mode or other options if needed
        }
    }

    // If Gradle supports Java toolchains in your environment, prefer this (safe fallback when available)
    plugins.withType(org.gradle.api.plugins.JavaPlugin::class.java) {
        extensions.configure(org.gradle.api.plugins.JavaPluginExtension::class.java) {
            toolchain {
                languageVersion.set(org.gradle.jvm.toolchain.JavaLanguageVersion.of(11))
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
