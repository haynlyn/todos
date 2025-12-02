CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY,
  user_id INTEGER,
  file_id INTEGER,
  line_start INTEGER,
  line_end INTEGER,
  priority INTEGER,
  content TEXT NOT NULL,  -- Required: The actual task description (todo.txt compatible)
  title TEXT,              -- Optional: Short summary/title (Jira-style)
  status TEXT,
  created_at TEXT,
  due_date TEXT,
  completed_at TEXT,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS files (
  id INTEGER PRIMARY KEY,
  path TEXT UNIQUE,
  tags TEXT,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- May just limit topics to ~63 different ones and use binary encoding for bridging stuff to topics with `power()`
CREATE TABLE IF NOT EXISTS topics (
  id INTEGER PRIMARY KEY,
  topic TEXT UNIQUE,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS projects (
  id INTEGER PRIMARY KEY,
  project TEXT UNIQUE,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS project_tasks (
  project_id INTEGER NOT NULL REFERENCES projects(id),
  task_id INTEGER NOT NULL REFERENCES tasks(id),
  PRIMARY KEY (project_id, task_id)
);

-- Is this one really needed?
CREATE TABLE IF NOT EXISTS project_users (
  project_id INTEGER NOT NULL REFERENCES projects(id),
  task_id INTEGER NOT NULL REFERENCES users(id),
  PRIMARY KEY (project_id, task_id)
);

CREATE TABLE IF NOT EXISTS project_topics (
  project_id INTEGER NOT NULL REFERENCES projects(id),
  task_id INTEGER NOT NULL REFERENCES topics(id),
  PRIMARY KEY (project_id, task_id)
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  user TEXT UNIQUE NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by TEXT
);

-- May just limit topics to ~63 different ones and use binary encoding for bridging tasks to topics with `power()`
CREATE TABLE IF NOT EXISTS task_topics (
  task_id INTEGER NOT NULL REFERENCES tasks(id),
  topic_id INTEGER NOT NULL REFERENCES topics(id),
  PRIMARY KEY (task_id, topic_id)
);

-- May just limit topics to ~63 different ones and use binary encoding for bridging users to topics with `power()`
CREATE TABLE IF NOT EXISTS user_topics (
  user_id INTEGER NOT NULL REFERENCES users(id),
  topic_id INTEGER NOT NULL REFERENCES topics(id),
  subscribed_at TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, topic_id)
);
