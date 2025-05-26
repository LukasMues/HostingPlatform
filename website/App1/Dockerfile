# For App1
FROM nginx:alpine
RUN rm -rf /usr/share/nginx/html/* && mkdir -p /usr/share/nginx/html
COPY . /usr/share/nginx/html/ # Copies from Website/App1/
# Add any other App1 specific Docker instructions
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]