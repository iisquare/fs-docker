ARG ELK_VERSION

FROM elasticsearch:${ELK_VERSION}

# 复制整个 plugins 目录（目录存在即可，里面有没有 zip 都不影响构建）
COPY plugins/ /tmp/plugins/

RUN if [ -f /tmp/plugins/analysis-ik-online-0.0.1.zip ]; then \
        unzip /tmp/plugins/analysis-ik-online-0.0.1.zip -d /usr/share/elasticsearch/plugins/analysis-ik-online/; \
        echo "✅ 插件安装成功"; \
    else \
        echo "⚠️ 未找到插件包，跳过安装"; \
    fi
RUN rm -rf /tmp/plugins

ENV discovery.type single-node
ENV http.cors.enabled true
ENV http.cors.allow-origin *

EXPOSE 9200 9300
