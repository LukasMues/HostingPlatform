    # For App1
    FROM nginx:alpine
    RUN rm -rf /usr/share/nginx/html/*
    COPY . /usr/share/nginx/html/ # Copies from Website/App1/
    EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]