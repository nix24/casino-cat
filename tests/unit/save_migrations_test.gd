extends TestCase
## SaveMigrations: only the current version is accepted until a second version exists (arch §6).


func test_version_1_is_unchanged() -> void:
	var data := {"version": 1, "hp": 41}
	assert_eq(SaveMigrations.upgrade(data), data)


func test_future_version_returns_empty() -> void:
	assert_true(SaveMigrations.upgrade({"version": 2}).is_empty())


func test_missing_version_returns_empty() -> void:
	assert_true(SaveMigrations.upgrade({"hp": 41}).is_empty())
