    # For App2
    FROM nginx:alpine 
    RUN rm -rf /usr/share/nginx/html/*
    COPY . /usr/share/nginx/html/ # Copies from Website/App2/
    # Add any other App2 specific Docker instructions
    EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]