# For App1 - Diagnostic Version
FROM nginx:alpine

# Step 1: Clean and create the directory, then list parent and target
RUN echo "Step 1: Cleaning and creating /usr/share/nginx/html" && \
    rm -rf /usr/share/nginx/html/* && \
    mkdir -v -p /usr/share/nginx/html && \
    echo "Listing /usr/share/nginx:" && \
    ls -la /usr/share/nginx && \
    echo "Listing /usr/share/nginx/html:" && \
    ls -la /usr/share/nginx/html && \
    echo "Permissions of /usr/share/nginx/html:" && \
    stat -c '%a %U:%G' /usr/share/nginx/html || echo "stat command failed for /usr/share/nginx/html"

# Step 2: Attempt to copy
COPY . /usr/share/nginx/html/

# Add any other App1 specific Docker instructions
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]