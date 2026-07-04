## Requirements

- Ruby 3.3.3+
- PostgreSQL 14+
- Google Gemini API key
- GitHub APP client id and client secret
- GitHub OAuth client id and client secret
## Build Steps

### 1. Clone and Install

```bash
git clone <repository-url>
cd github_bot
bundle install
```

### 2. Configure Environment

Create `.env` file:

```bash
GEMINI_API_KEY=your_gemini_api_key
POSTGRES_PASSWORD=your_password
GITHUB_APP_ID=your_github_app_id
GITHUB_APP_PRIVATE_KEY_PATH=/path/to/private-key.pem
GITHUB_CLIENT_ID=your_github_oauth_client_id
GITHUB_CLIENT_SECRET=your_github_oauth_client_secret
```

### 3. Setup Database

```bash
rails db:create
rails db:migrate
```

### Start the Application

```bash
bin/dev
```

This starts:
- Rails server on http://localhost:3000
- Background job processor
- CSS watcher

The application is now running and ready to use.

### Alternative: Start Services Separately

```bash
# Terminal 1
rails server

# Terminal 2
bin/jobs

# Terminal 3
rails tailwindcss:watch
```
