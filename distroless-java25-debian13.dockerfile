# Required libs
ARG NATIVE_LIBS

# Collect the native GL/EGL libraries needed by the graphics stack (Skija) using
# the same Debian 13 (trixie) base as gcr.io/distroless/java25-debian13 to ensure
# ABI compatibility.
FROM docker.io/debian:trixie-slim AS native-libs

RUN set -eux; \
    dpkg-query -f '${Package}\n' -W | sort > /baseline.txt; \
    apt-get update; \
    apt-get install -y --no-install-recommends ${NATIVE_LIBS}; \
    rm -rf /var/lib/apt/lists/*; \
    dpkg-query -f '${Package}\n' -W | sort > /installed.txt; \
    comm -13 /baseline.txt /installed.txt > /new-packages.txt; \
    mkdir -p /collected; \
    while IFS= read -r pkg; do \
        dpkg -L "$pkg" 2>/dev/null | grep -E '^/(usr/)?lib/' | while IFS= read -r f; do \
            { [ -f "$f" ] || [ -L "$f" ]; } && cp -a --parents "$f" /collected; \
        done; \
    done < /new-packages.txt

FROM gcr.io/distroless/java25-debian13 AS final

WORKDIR /app

# Copy native OpenGL/EGL libraries (and their transitive deps) required by the
# graphics rendering stack (Skija). The original filesystem paths are preserved
# so they reside in standard Debian multiarch library locations.
COPY --from=native-libs /collected/ /

# Ensure the dynamic linker in the distroless base can locate the copied native
# libraries, including those installed under multiarch directories.
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu"
