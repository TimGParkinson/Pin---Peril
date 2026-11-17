class_name UiMetrics
extends RefCounted
## Shared presentation constants for scalable, touch-friendly UI.

## Design-space viewport. Must equal the project display/window/size settings.
const DESIGN_SIZE: Vector2i = Vector2i(1920, 1080)

## Minimum interactive control size in design units (touch-friendly hit area).
const MIN_HIT_SIZE: Vector2 = Vector2(96.0, 96.0)

## Minimum keyboard-focus ring thickness in design units. The ring must stay clearly visible
## on both light (cream) and dark (teal) backgrounds. See themes/base_theme.tres.
const MIN_FOCUS_RING_WIDTH: int = 4

## Default button size for primary menu actions.
const PRIMARY_BUTTON_SIZE: Vector2 = Vector2(360.0, 96.0)
