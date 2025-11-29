#!/usr/bin/env python3
"""Sample Python file with TODO comments for testing"""

def authenticate_user(username, password):
    """Authenticate a user with username and password"""
    # TODO: Add rate limiting to prevent brute force attacks
    if not username or not password:
        return False

    # FIXME: This is vulnerable to SQL injection
    query = f"SELECT * FROM users WHERE username = '{username}'"

    # TODO: Hash password before comparison
    return True

def send_email(to_address, subject, body):
    """Send an email to the specified address"""
    # NOTE: Currently using mock SMTP server
    # XXX: Need to add retry logic for failed sends
    pass

# TODO: {
#   Implement proper error handling for email failures
#   Add logging for all email operations
#   Support HTML email templates
# }

class UserManager:
    # TODOS.START
    # Add method to bulk import users from CSV
    # Implement user deactivation instead of deletion
    # Add audit logging for all user operations
    # TODOS.END

    def create_user(self, username, email):
        # HACK: Temporary workaround for duplicate emails
        pass
