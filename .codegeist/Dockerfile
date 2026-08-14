# .codegeist/Dockerfile - Flutter and Android toolchain for Codegeist App
#
# Why this exists:
# - Extends the shared devcontainer with the Android-only Flutter toolchain
#   required by docs/tasks/T001_bootstrap_minimal_flutter_android_app.md.
# - Adds the scrcpy mirror used by the visible Android workflow from
#   docs/tasks/T003_use_scrcpy_for_visible_android.md.
#
# Inputs:
# - The shared image provides CONTAINER_USER and the QEMU/KVM runtime packages.
#
# Side effects:
# - Installs project SDK and pinned scrcpy inputs under /opt and warms Flutter's
#   Android cache.
# - Accepts the Android SDK licenses required for non-interactive builds.
#
# Related files:
# - .devcontainer/initialize.sh
# - scripts/android-avd.sh

USER root

ARG FLUTTER_VERSION=3.47.0
ARG FLUTTER_SHA256=26cd99d3d94b1367e6b50535a18aeef0282c10a535bbe3ec493534dcdab75296
ARG JDK_VERSION=21.0.12_8
ARG JDK_SHA256=e4446ff06a276155697597cc0f1b15da004ff083f4964a35271ecee567177370
ARG ANDROID_CMDLINE_TOOLS_BUILD=15859902
ARG ANDROID_CMDLINE_TOOLS_SHA1=040d3996a65543d22ec4bf73e4c37aa37a8d4af4
ARG ANDROID_PLATFORM=36
ARG ANDROID_BUILD_TOOLS_REVISION=36.0.0
ARG ANDROID_NDK_REVISION=28.2.13676358
ARG SCRCPY_VERSION=4.1
ARG SCRCPY_SHA256=ad56ae8bfeedf41e824945c11dbf55fcb092b3e615b9b486f48a50e30d389635

ENV JAVA_HOME=/opt/jdk-21 \
    FLUTTER_ROOT=/opt/flutter \
    ANDROID_HOME=/opt/android-sdk \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    SCRCPY_SERVER_PATH=/opt/scrcpy/scrcpy-server \
    PUB_CACHE=/home/${CONTAINER_USER}/.pub-cache \
    PATH=/opt/jdk-21/bin:/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:${PATH}

RUN curl -fsSL \
      "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12%2B8/OpenJDK21U-jdk_x64_linux_hotspot_${JDK_VERSION}.tar.gz" \
      -o /tmp/jdk.tar.gz \
 && printf '%s  %s\n' "$JDK_SHA256" /tmp/jdk.tar.gz | sha256sum -c - \
 && install -d -m 0755 "$JAVA_HOME" \
 && tar -xzf /tmp/jdk.tar.gz --strip-components=1 -C "$JAVA_HOME" \
 && rm -f /tmp/jdk.tar.gz \
 && java -version

RUN curl -fsSL \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter.tar.xz \
 && printf '%s  %s\n' "$FLUTTER_SHA256" /tmp/flutter.tar.xz | sha256sum -c - \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm -f /tmp/flutter.tar.xz \
 && chown -R "$CONTAINER_USER:$CONTAINER_GROUP" "$FLUTTER_ROOT" \
 && su "$CONTAINER_USER" -c \
      "HOME=/home/$CONTAINER_USER flutter --version"

RUN curl -fsSL \
      "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip" \
      -o /tmp/android-command-line-tools.zip \
 && printf '%s  %s\n' "$ANDROID_CMDLINE_TOOLS_SHA1" /tmp/android-command-line-tools.zip | sha1sum -c - \
 && install -d -m 0755 "$ANDROID_SDK_ROOT/cmdline-tools/latest" /tmp/android-command-line-tools \
 && unzip -q /tmp/android-command-line-tools.zip -d /tmp/android-command-line-tools \
 && cp -a /tmp/android-command-line-tools/cmdline-tools/. "$ANDROID_SDK_ROOT/cmdline-tools/latest/" \
 && rm -rf /tmp/android-command-line-tools /tmp/android-command-line-tools.zip

RUN yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null \
 && sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
      "platform-tools" \
      "emulator" \
      "platforms;android-${ANDROID_PLATFORM}" \
      "build-tools;${ANDROID_BUILD_TOOLS_REVISION}" \
      "system-images;android-${ANDROID_PLATFORM};google_apis;x86_64" \
      "ndk;${ANDROID_NDK_REVISION}"

RUN curl -fsSL \
      "https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VERSION}/scrcpy-linux-x86_64-v${SCRCPY_VERSION}.tar.gz" \
      -o /tmp/scrcpy.tar.gz \
 && printf '%s  %s\n' "$SCRCPY_SHA256" /tmp/scrcpy.tar.gz | sha256sum -c - \
 && install -d -m 0755 /opt/scrcpy \
 && tar -xzf /tmp/scrcpy.tar.gz --strip-components=1 -C /opt/scrcpy \
 && ln -s /opt/scrcpy/scrcpy /usr/local/bin/scrcpy \
 && rm -f /tmp/scrcpy.tar.gz \
 && scrcpy --version

RUN su "$CONTAINER_USER" -c \
      "HOME=/home/$CONTAINER_USER flutter config --no-analytics" \
 && su "$CONTAINER_USER" -c \
      "HOME=/home/$CONTAINER_USER flutter precache --android" \
 && su "$CONTAINER_USER" -c \
      "HOME=/home/$CONTAINER_USER flutter doctor -v"

USER ${CONTAINER_USER}
