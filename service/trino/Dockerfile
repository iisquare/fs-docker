ARG TRINO_VERSION
FROM trinodb/trino:${TRINO_VERSION}

ARG TRINO_VERSION

# 切换为 root 以便拥有写入权限
USER root

# 复制插件包（暂存于 /tmp）
COPY plugins/ /tmp/plugins/

# 使用 Java 自带的 jar 命令解压插件（无需安装 unzip）
RUN set -eux; \
    if [ -f /tmp/plugins/fs-trino-${TRINO_VERSION}.zip ]; then \
        mkdir -p /usr/lib/trino/plugin/fs-trino; \
        cd /usr/lib/trino/plugin/fs-trino && \
        jar xf /tmp/plugins/fs-trino-${TRINO_VERSION}.zip; \
        echo "✅ 插件安装成功"; \
    else \
        echo "⚠️ 未找到插件包，跳过安装"; \
    fi

# 清理临时文件并修正插件目录权限（确保 trino 用户可读）
RUN rm -rf /tmp/plugins && \
    chown -R trino:trino /usr/lib/trino/plugin

# 恢复为 trino 用户运行
USER trino

EXPOSE 8080 8443
