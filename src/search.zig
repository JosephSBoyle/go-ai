const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

const board = @import("board.zig");
const GameState = board.GameState;


/// black is maximizing and white is minimizing black's score.
/// without alpha-beta pruning or the super-ko rule (not implemented),
/// this algorithm will never terminate, as each player will capture the other's stones forever.
fn minimax(comptime GameStateT : type, state : *GameStateT, depth : u64) i64 {
    if (state.finished or depth == 10) {
        print("FINISHED AFTER WITH POSITION:\n", .{});
        _ = state.renderBoard();
        // print("{any}", .{state.areaScore().black_score});
        const score = state.areaScore();
        return score.black_score - score.white_score;
    }

    if (state.blacks_move) {
        // maximizing player's turn
        var value : i64 = 0;
        for (0..GameStateT.length) |i| {
            for (0..GameStateT.length) |j| {
                var child_state = state.copy();
                


                if (child_state.playStone(@intCast(i), @intCast(j))) {
                    for (0..depth) |_| {print(" ", .{});}
                    print("BLACK PLAYING MOVE : {any},{any}\n", .{i, j});
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
                    for (0..depth) |_| {print("  ", .{});}
                    print("WHITE PLAYING MOVE : {any},{any}\n", .{i, j});
                    print("{any}\n", .{child_state.renderBoard()});
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

/// Implementation of the minimax algorithm for selecting moves
/// 
/// Evaluates all possible combinations of moves and, at each move,
/// selects the one which maximizes utility for the current player.
fn playMinimaxMove(comptime GameStateT : type, state: *GameStateT) GameStateT {
    // const maximizing_player = state.blacks_move;

    // if (maximizing_player) {
    //     var value : i64 = @typeInfo(i64).Int.min;

    // } else {
    //     var value : i64 = @typeInfo(i64).Int.max;

    // }

    // // enumerate valid child nodes (i.e. all valid moves)
    // for (state.board, 0..) |row, i| {
    //     for (row, 0..) |vertex, j| {
    //         if (vertex != 0) {
    //             // The vertex must be empty to be a legal move.
    //             // (necessary but not sufficient condition).
    //             continue;
    //         }
    //     }
    // }


    // No legal moves found!
    return state.passTurn();
}

// TODO make this run only in testing.
const OneByOne     = GameState(1);
const TwoByTwo     = GameState(2);
// const ThreeByThree = GameState(3);

// test "minimax for a 1x1 grid leads to a score of 0 for black" {
//     var state = OneByOne.init();
//     try expect(minimax(OneByOne, &state) == 0);
// }

test "minimax for a 2x2 grid leads to a score of 1 for black" {
    var state = TwoByTwo.init();
    // e.g.
    // 10 -> 10 -> 10 -> 10 
    // 00    02    02    20
    // and the game ends due to double pass.

    _ = state.playStone(0, 0);
    _ = state.playStone(1, 1);
    
    // // maximizing player's turn
    // var value : i64 = 0;
    // for (0..TwoByTwo.length) |i| {
    //     for (0..TwoByTwo.length) |j| {
    //         var child_state = state.copy();
    //         // print("BLACK PLAYING MOVE : {any}{any}\n", .{i, j});

    //         if (child_state.playStone(@intCast(i), @intCast(j))) {
    //             print("{any},{any} :{any}\n", .{i, j, value});
    //             value =  @max(value, child_state.areaScore().black_score);
    //             // value = @max(value, minimax(TwoByTwo, &child_state));
    //         }
    //     }
    // }
    // var pass_state = state.copy();
    // pass_state.passTurn();
    // value = @max(value, minimax(TwoByTwo, &pass_state));
    // try expect(value == 1);
    
    
    try expect(minimax(TwoByTwo, &state, 0) == 1);
}

// test "generates a move" {
//     var state = TwoByTwo.init();
//     _ = getMoveMinimax(TwoByTwo, &state);
// }

// test "test does not play illegal move" {
//     var state = TwoByTwo.init();
//     _ = state.playStone(0, 0);
//     _ = state.passTurn();
//     _ = state.playStone(1, 1);
    
//     _ = state.renderBoard();
//     // white now has no legal moves, they *must* pass.
//     const move = getMoveMinimax(OneByOne, &state);
//     print("{any}", .{move});
//     try expect(move[0] == null);
//     try expect(move[1] == null);
// }