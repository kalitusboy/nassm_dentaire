"""Adapte le projet Android généré par `flutter create` :
 - Android Gradle Plugin 8.6 + Gradle 8.7 + compileSdk 35 (les plugins récents l'exigent ;
   l'ancien AGP 7.3 ne sait pas lire android-35.jar)
 - Kotlin récent (les plugins comme shared_preferences l'exigent)
 - désucrage Java (flutter_local_notifications)
 - permission Internet + HTTP en clair (le serveur du cabinet est en http://IP:8090)
"""
import pathlib
import re
import shutil

KOTLIN = "1.9.22"
root = pathlib.Path("android")


def edit(path, fn):
    p = root / path
    if not p.exists():
        return False
    s = p.read_text(encoding="utf-8")
    n = fn(s)
    if n != s:
        p.write_text(n, encoding="utf-8")
        print("patched", p)
    return True


# 1) Kotlin
def kotlin_settings(s):
    return re.sub(r'(org\.jetbrains\.kotlin\.android"\s+version\s+")[\d.]+(")',
                  r"\g<1>%s\g<2>" % KOTLIN, s)


def kotlin_legacy(s):
    return re.sub(r"(ext\.kotlin_version\s*=\s*')[\d.]+(')", r"\g<1>%s\g<2>" % KOTLIN, s)


AGP = "8.6.0"
GRADLE = "8.7"


def agp_settings(s):
    return re.sub(r'(com\.android\.application"\s+version\s+")[\d.]+(")', r"\g<1>%s\g<2>" % AGP, s)


def agp_legacy(s):
    return re.sub(r"(com\.android\.tools\.build:gradle:)[\d.]+", r"\g<1>%s" % AGP, s)


edit("settings.gradle", agp_settings)
edit("build.gradle", agp_legacy)
edit("gradle/wrapper/gradle-wrapper.properties", lambda s: re.sub(
    r"gradle-[\d.]+-(all|bin)\.zip", r"gradle-%s-all.zip" % GRADLE, s))

edit("settings.gradle", kotlin_settings)
edit("settings.gradle.kts", lambda s: re.sub(
    r'(org\.jetbrains\.kotlin\.android"\)?\s*version\s*"?)[\d.]+', r"\g<1>%s" % KOTLIN, s))
edit("build.gradle", kotlin_legacy)


# 2) Désucrage
def desugar(s):
    if "coreLibraryDesugaringEnabled" not in s:
        s = re.sub(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", s, count=1)
    if "desugar_jdk_libs" not in s:
        dep = "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n}\n"
        if re.search(r"^dependencies\s*\{", s, re.M):
            s = re.sub(r"^(dependencies\s*\{)", r"\1\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'",
                       s, count=1, flags=re.M)
        else:
            s += dep
    # compileSdk 35
    s = re.sub(r"compileSdkVersion\s+flutter\.compileSdkVersion", "compileSdkVersion 35", s)
    s = re.sub(r"compileSdk\s*=?\s*flutter\.compileSdkVersion", "compileSdk = 35", s)
    # 2b) Désactive « lintVital » : plante avec D8/R8 (D8BackportedMethodsGenerator)
    #     et n'a aucun effet sur l'APK produit.
    if "checkReleaseBuilds" not in s:
        s = re.sub(r"(android\s*\{)", r"\1\n    lint {\n        checkReleaseBuilds false\n        abortOnError false\n    }", s, count=1)
    return s


edit("app/build.gradle", desugar)


# 3) Manifeste
def manifest(s):
    perms = ["android.permission.INTERNET", "android.permission.POST_NOTIFICATIONS"]
    for perm in perms:
        if perm not in s:
            s = re.sub(r"(<manifest[^>]*>)", r'\1\n    <uses-permission android:name="%s"/>' % perm, s, count=1)
    if "usesCleartextTraffic" not in s:
        s = re.sub(r"<application", '<application\n        android:usesCleartextTraffic="true"', s, count=1)
    return s


edit("app/src/main/AndroidManifest.xml", manifest)


# 4) Nom et icônes de l'application
def label(s):
    return re.sub(r'android:label="[^"]*"', 'android:label="DentaGest"', s, count=1)


edit("app/src/main/AndroidManifest.xml", label)

icons = pathlib.Path("assets/android_icons")
if icons.exists():
    for d in icons.iterdir():
        src = d / "ic_launcher.png"
        if src.exists():
            dst = root / "app/src/main/res" / d.name
            dst.mkdir(parents=True, exist_ok=True)
            shutil.copy(src, dst / "ic_launcher.png")
            print("icon", dst)
