# Here we are using AStar2D and overriding its cost rules.
extends AStar2D
class_name WeightedAStar

# A star2d func that tells the node what each step costs. We are replacing it with our own costs.
func _compute_cost(from_id: int, to_id: int) -> float:
	var from_pos := get_point_position(from_id)
	var to_pos := get_point_position(to_id)
	# Differences on each axis, tells it if its diagonal or now, basically.
	var dx: float = abs(from_pos.x - to_pos.x)
	var dy: float = abs(from_pos.y - to_pos.y)
	if dx > 0 and dy > 0:
	# The new costs. 3 for diagonal, else 2.
		return 3.0
	return 2.0

# This overrides the astar2d pathfinding so that it takes in mind the new costs, 2 and 3.
func _estimate_cost(from_id: int, to_id: int) -> float:
	var from_pos := get_point_position(from_id)
	var to_pos := get_point_position(to_id)
	# These calculations & vars bascially mean that diagonals are favoured unless the point to get 
	# to is exactly ahead on one axis, in which case orthogonal steps are cheaper.
	var dx: float = abs(from_pos.x - to_pos.x)
	var dy: float = abs(from_pos.y - to_pos.y)
	# Minimum out of the two IDs.
	var mn: float = min(dx, dy)
	# Max out of the two IDs.
	var mx: float = max(dx, dy)
	# The optimal path between two points (with no obstacles) is: take min(dx, dy) diagonal steps to
	# cover both axes simultaneously, then max(dx, dy) - min(dx, dy) orthogonal steps to finish the
	# remaining axis. So the minimum possible cost is mn × 3 + (mx − mn) × 2. Uses the same costs
	# as compute, obviously.
	# Below formula is the key to everything. As an example, 2 diagonal steps x 3 MP cost 6 MP.
	# 3 normal steps x 2MP cost 6MP. The total cost is 12MP. Putting that into the below formula:
	# below formula = 2(diagonals)x3(MP) + 3(normal)x2(MP) = 6+6 = 12MP. 
	return mn * 3.0 + (mx - mn) * 2.0

## FURTHER EXPLANATION
# Concrete example. Lets say you're going from (0, 0) to (5, 2).
#
# dx = 5 — total horizontal distance to cover
# dy = 2 — total vertical distance to cover
# mn(the minimum out of the two) = 2, mx(the max out of the two) = 5
#
# You take 2 diagonal steps first. Each diagonal step moves you 1 on the x axis AND 1 on the y axis.
# So after 2 diagonals:
#
# x has moved by 2 out of the 5 needed (3 left)
# y has moved by 2 out of the 2 needed (0 left, DONE!)
#
# The y axis is fully covered because it was done with diagonals. But the x axis still has 3 tiles
# left to cover, since each diagonal only contributed 1 to x. So the leftover on the longer axis is
# dx - dy, which in the general formula is mx - mn. Those leftover tiles can only be done
# orthogonally since the shorter axis is already complete. That mx - mn is how many tiles still need
# covering on the longer axis, whatever that is, and each one mut be an orthogonal step.
