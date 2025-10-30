-- Create tags
INSERT OR IGNORE INTO test_tags (tag) VALUES ('USERS'), ('DB'), ('LOGS'), ('BUG');

-- Create todos-managed todos
INSERT INTO test_todos (todo, tags, status) VALUES
("Add to name-change feature to user profile.", "USERS", "NOT STARTED"),
("Add capability to provide custom db connection.", "DB", "WIP"),
("Implement logging in another SQLite3 db.", "LOGS,DB"),
("Figure out a tag for this item?", NULL, "WIP"),
("Make some test cases for TODOS.", "META", "DONE")
  ;
