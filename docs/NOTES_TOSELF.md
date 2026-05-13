## Multiplayer Testing Notes

### Working as Designed
1. **Team Open Games** — When going through team → open → games, it's working as an invite game. This is not a problem for open FFA games — it works as designed.

### UI/UX Issues
2. **Lobby Button Colors** — Button colors for joining don't match the color you are joining. Buttons are already pink and purple. May need to rethink color palette of buttons in lobby.

3. **Lobby Game Info Text** — Info text (right hand corner) when hovering over a game is not helpful. Should show:
   - "game not started" or "waiting for x player" — before game starts
   - Once waiting room is active: show player scores OR team scores (for team games)
   - Note if game is active or not — if active, show time on it
   - Reference: Look at how 1v1 works for the text style/approach

4. **Host Info Button Color** — The host's info button (about the room) is often missing the color coding that the others have.

5. **Invite Mode Waiting Copy** — When in invite mode and a player leaves, the copy should say "waiting for X number players to start" instead of specifying who you're waiting for.

6. **Waiting Room Host Indicator** — In the waiting room, indicate who the host is.

7. **Player Death Time Marker** — Should give a time marker (saved) for when a player died, displayed above the player name.

### Critical Bugs 🔴
8. **Lobby Player List Bug** — When one player leaves, the lobby incorrectly shows only the host being present, even though other players are still there. Example:
   ```
   Amber 
   (waiting...)
   (your seat --clic to rejoin)
   ```

9. **Ready State Mismatch Bug** — The ready state is mismatched at times—shows "read" when the player did not click ready. 
   **Scenario:**
   - Game play (3 team, invite mode)
   - A couple games played
   - 2 players go back to lobby (p1, p2)
   - p2 leaves and returns
   - p1, p2 click ready → but shows as p3 ready
   - p3 goes back to waiting room (was at end game screen)
   - Shows NOT ready, but reads p1, p2 as ready
   - Once p3 clicks ready, game starts but shows incorrectly in UI for p1, p2

10. **Game State Sync Freeze Bug** — **[PRIORITY - COMING BACK TO THIS]** Game freezes on end with desynchronized player states.
    **Scenario:** Next game p1 vs p2, p3. p2 and p3 died but:
    - From p1's perspective: p2 died, p3 was halfway up on screen (not moving)
    - From p2's perspective: p3 was halfway up on screen (not moving)  
    - From p3's perspective: Only p3 saw they were actually done
    **Result:**
    - p1 was stuck playing forever
    - Once p1 lost, there was no draw/end game marker
    - Game froze for ALL players
    **Note:** This appears to be a game state synchronization + end-game detection bug where clients have different states about who is alive/dead.

11. **Timeout Broken Game Handling** — When timeout occurs, there are no errors shown, but the game becomes broken (nothing is happening). Should not force reload on timeout.

---

**Remember:** Check docs/TRACE_LOGS_GUIDE.md
