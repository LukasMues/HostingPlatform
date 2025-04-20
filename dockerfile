# Use official Nginx image
FROM nginx:alpine

# Remove default Nginx HTML files
RUN rm -rf /usr/share/nginx/html/*

# Copy your website files to the Nginx HTML folder
COPY Website/ /usr/share/nginx/html/

# Expose port 80 (Nginx default)
EXPOSE 80

# Start Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
