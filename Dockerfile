FROM httpd:2.4

RUN apt-get update && apt-get install -y --no-install-recommends \
    perl \
    libcgi-pm-perl \
    libdbi-perl \
    libdbd-sqlite3-perl \
    tzdata \
  && rm -rf /var/lib/apt/lists/*

# Set MSK timezone (as in reference work)
RUN ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime && \
    echo "Europe/Moscow" > /etc/timezone

# Static site + assets
COPY static/ /usr/local/apache2/htdocs/
COPY assets/ /usr/local/apache2/htdocs/assets/

# CGI + shared perl libs
COPY perl/cgi/ /usr/local/apache2/cgi-bin/
COPY perl/lib/ /opt/app/lib/
ENV PERL5LIB="/opt/app/lib"

# Data dir for SQLite (mounted via compose)
RUN mkdir -p /data && chmod 777 /data

# Permissions (don't fail if no CGI yet)
RUN chmod +x /usr/local/apache2/cgi-bin/*.pl 2>/dev/null || true

# Enable CGI (as in reference work)
RUN echo "LoadModule cgi_module modules/mod_cgi.so" >> /usr/local/apache2/conf/httpd.conf && \
    echo "ScriptAlias /cgi-bin/ \"/usr/local/apache2/cgi-bin/\"" >> /usr/local/apache2/conf/httpd.conf && \
    echo "<Directory \"/usr/local/apache2/cgi-bin\">" >> /usr/local/apache2/conf/httpd.conf && \
    echo "    AllowOverride None" >> /usr/local/apache2/conf/httpd.conf && \
    echo "    Options +ExecCGI" >> /usr/local/apache2/conf/httpd.conf && \
    echo "    Require all granted" >> /usr/local/apache2/conf/httpd.conf && \
    echo "</Directory>" >> /usr/local/apache2/conf/httpd.conf && \
    echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80
CMD ["httpd-foreground"]

