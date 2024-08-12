const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

const board = @import("board.zig");
const GameState = board.GameState;

/// Implementation of the minimax algorithm for selecting moves
/// 
/// Evaluates all possible combinations of moves and, at each move,
/// selects the one which maximizes utility for the current player.
fn getMoveMinimax(comptime GameStateT : type, state: *GameStateT) struct {?i8, ?i8} {

    // enumerate valid child nodes (i.e. all valid moves)
    for (state.board, 0..) |row, i| {
        for (row, 0..) |vertex, j| {
            if (vertex != 0) {
                // The vertex must be empty to be a legal move.
                // (necessary but not sufficient condition).
                continue;
            }

        }
    }


    // No legal moves found!
    return .{null, null};
}

// TODO make this run only in testing.
const OneByOne     = GameState(1);
const TwoByTwo     = GameState(2);
// const ThreeByThree = GameState(3);

test "generates a move" {
    var state = TwoByTwo.init();
    _ = getMoveMinimax(TwoByTwo, &state);
}

test "test does not play illegal move" {
    var state = TwoByTwo.init();
    _ = state.playStone(0, 0);
    _ = state.passTurn();
    _ = state.playStone(1, 1);
    
    _ = state.renderBoard();
    // white now has no legal moves, they *must* pass.
    const move = getMoveMinimax(OneByOne, &state);
    print("{any}", .{move});
    try expect(move[0] == null);
    try expect(move[1] == null);
}