# Hosting Platform - Quick Start Guide

## What You Need to Do

1. Place your website files in the `Website/` directory
   - Make sure your main page is named `index.html`
      <span style="color:red">If your main page has a different name, please contact our support team</span>
   - Include all your website assets (CSS, JavaScript, images, etc.)
   

2. Commit and push your changes to GitHub
   ```bash
   git add .
   git commit -m "Update website"
   git push origin main
   ```

## What Happens After You Commit

Once you push your changes:
1. Jenkins automatically detects the new commit
2. Your website is built into a Docker container
3. The container is pushed to Docker Hub
4. Your website is deployed and ready to use

That's it! Your website will be automatically updated whenever you push new changes to GitHub. 