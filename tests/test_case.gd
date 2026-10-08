class_name TestCase
extends RefCounted
## Base class for headless tests. Methods named `test_*` run in file order.
##
## Assertions record a failure message and let the test continue, so one run reports every
## broken expectation. tests/run_tests.gd discovers subclasses under tests/unit and tests/sim.

var failures: PackedStringArray = []
var _current_test: String = ""


## Called by the runner before each test method.
func begin(test_name: String) -> void:
	_current_test = test_name


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		_fail("expected %s, got %s. %s" % [expected, actual, message])


func assert_almost_eq(
	actual: float, expected: float, tolerance: float, message: String = ""
) -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s. %s" % [expected, tolerance, actual, message])


func _fail(text: String) -> void:
	failures.append("%s: %s" % [_current_test, text])
