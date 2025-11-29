#!/bin/sh
# Unit tests for topic operations

# Load test helpers
. "$(dirname "$0")/../test_helpers.sh"

# Load library
LIBDIR=$(get_lib_path)
. "$LIBDIR/topics.sh"

echo "${BLUE}Running Topic Tests${NC}"
echo "========================================"

# Test 1: Subscribe to topic
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
assert_row_exists "topics" "topic = 'work'" "Topic 'work' should be created"
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'work';")
assert_row_exists "user_topics" "user_id = $user_id AND topic_id = $topic_id" "User should be subscribed to topic"
teardown_test

# Test 2: Subscribe to multiple topics
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
subscribe_topic -u testuser "personal" > /dev/null 2>&1
subscribe_topic -u testuser "urgent" > /dev/null 2>&1
assert_db_count "topics" 3 "Should have 3 topics"
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM user_topics WHERE user_id = $user_id;")
assert_equal "3" "$count" "User should be subscribed to 3 topics"
teardown_test

# Test 3: Subscribe to same topic twice (should be ignored)
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
subscribe_topic -u testuser "work" > /dev/null 2>&1
assert_db_count "topics" 1 "Should have only 1 topic despite duplicate subscription"
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
count=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM user_topics WHERE user_id = $user_id;")
assert_equal "1" "$count" "Should have only 1 subscription"
teardown_test

# Test 4: Unsubscribe from topic
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
unsubscribe_topic -u testuser "work" > /dev/null 2>&1
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'work';")
assert_row_not_exists "user_topics" "user_id = $user_id AND topic_id = $topic_id" "User should be unsubscribed"
teardown_test

# Test 5: Orphaned topic detection
setup_test
subscribe_topic -u testuser "orphan" > /dev/null 2>&1
result=$(unsubscribe_topic -u testuser "orphan" 2>&1)
assert_contains "$result" "orphaned" "Should detect orphaned topic"
teardown_test

# Test 6: Topic with subscribers and tasks (not orphaned)
setup_test
# Add another user
sqlite3 "$TEST_DB" "INSERT INTO users (user) VALUES ('alice');"
alice_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'alice';")

subscribe_topic -u testuser "shared" > /dev/null 2>&1
user_id=$(sqlite3 "$TEST_DB" "SELECT id FROM users WHERE user = 'testuser';")
topic_id=$(sqlite3 "$TEST_DB" "SELECT id FROM topics WHERE topic = 'shared';")

# Subscribe alice too
sqlite3 "$TEST_DB" "INSERT INTO user_topics (user_id, topic_id) VALUES ($alice_id, $topic_id);"

result=$(unsubscribe_topic -u testuser "shared" 2>&1)
assert_not_contains "$result" "orphaned" "Topic with other subscribers should not be orphaned"
teardown_test

# Test 7: List topics for user
setup_test
subscribe_topic -u testuser "work" > /dev/null 2>&1
subscribe_topic -u testuser "personal" > /dev/null 2>&1
result=$(list_topics -u testuser 2>/dev/null)
assert_contains "$result" "work" "List should contain 'work' topic"
assert_contains "$result" "personal" "List should contain 'personal' topic"
teardown_test

# Test 8: Topic with special characters
setup_test
subscribe_topic -u testuser "urgent-2024" > /dev/null 2>&1
assert_row_exists "topics" "topic = 'urgent-2024'" "Topic with dash should be created"
teardown_test

print_summary
