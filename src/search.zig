const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

const board = @import("board.zig");
const GameState = board.GameState;

/// black is maximizing and white is minimizing black's score.
/// without a max-depth or the super-ko rule (not implemented),
/// this algorithm will never terminate, as each player will capture the other's stones forever.
fn minimax(comptime GameStateT : type, state : *GameStateT, depth : u64) i64 {
    const max_depth_reached = (depth == comptime std.math.pow(u64, GameStateT.length, 2));
    if (state.finished or max_depth_reached) {
        const score = state.areaScore();

        // black's score alone is sufficient to determine the winner,
        // unless playing in a ruleset with seki, which we are not.
        // see: https://senseis.xmp.net/?ChineseCounting#3
        const value = @as(i64, score.black_score);
        
        return value;
    }

    if (state.blacks_move) {
        // maximizing player's turn
        var value : i64 = 0;
        for (0..GameStateT.length) |i| {
            for (0..GameStateT.length) |j| {
                var child_state = state.copy();

                if (child_state.playStone(@intCast(i), @intCast(j))) {
                    value = @max(value, minimax(GameStateT, &child_state, depth+1));
                }
            }
        }
        var pass_state = state.copy();
        pass_state.passTurn();
        value = @max(value, minimax(GameStateT, &pass_state, depth+1));
        return value;
    } else {
        // minimizing player's turn
        var value : i64 = std.math.maxInt(i64);
        for (0..GameStateT.length) |i| {
            for (0..GameStateT.length) |j| {
                var child_state = state.copy();

                if (child_state.playStone(@intCast(i), @intCast(j))) {
                    value = @min(value, minimax(GameStateT, &child_state, depth+1));
                }
            }
        }
        var pass_state = state.copy();
        pass_state.passTurn();
        value = @min(value, minimax(GameStateT, &pass_state, depth+1));
        return value;
    }
}

// TODO make this run only in testing.
const OneByOne     = GameState(1);
const TwoByTwo     = GameState(2);
const ThreeByThree = GameState(3);
const FourByFour   = GameState(4);
const FiveByFive   = GameState(5);

test "minimax for a 1x1 grid leads to a score of 0 for black" {
    var state = OneByOne.init();
    try expect(minimax(OneByOne, &state, 0) == 0);
}

test "minimax from position leads to a score of 1 for black" {
    var state = TwoByTwo.init();

    _ = state.playStone(0, 0);
    _ = state.playStone(1, 1);
    // 10 -> 10 -> 10 -> 10 
    // 00    02    02    20
    // and the game ends due to double pass.
    try expect(minimax(TwoByTwo, &state, 0) == 1);
}

test "minimax for an empty 2x2 grid leads to a score of 1 for black" {
    var state = TwoByTwo.init();
    try expect(minimax(TwoByTwo, &state, 0) == 1);
}

test "minimax for an empty 3x3 grid leads to a score of 4 for black" {
    var state = ThreeByThree.init();
    try expect(minimax(ThreeByThree, &state, 0) == 4);
}

test "minimax for a 4x4 grid doesn't terminate without alpha-beta pruning" {
    var state = FourByFour.init();
    _ = minimax(FourByFour, &state, 0);
}