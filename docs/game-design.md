# All Inclusive — first playable design

**Baseline management design, with historical upgrade pricing.** Revision 3 keeps the day/guest/pricing loop but adds editable layouts and construction modes. The old $420, Day 2, one-click terrace purchase below is superseded: an accessible pair of loungers and an umbrella physically furnish the pool, with Regular catalog costs or free Developer placement. Booking counts are capped by the applied layout's usable bedrooms. See `revision-3.md` for current construction and safe application rules.

## The run

Manage a small family resort through three days of 240 simulation seconds each. The clock starts after the welcome screen. A run takes 12 minutes at 1× before player pauses. The final recap reports all three targets independently and offers Continue, a fresh run or loading the saved run. Continue opens Day 4 and later sandbox days while preserving the three-day milestone recap.

- Complete at least **8 family stays** by the end of Day 3.
- Earn an average checkout rating of **75/100** or higher.
- Buy the **pool terrace** upgrade.

The resort uses a three-quarter-view pixel-art map with four family bedrooms, a reception desk, a buffet and a pool. Revision 2 expands the terrain to 960 × 600 pixels with bounded pan and zoom, while preserving facility and guest coordinates. Management icons open one contextual panel at a time above the world; status remains in screen space. Each family has an adult and a smaller child companion who follows the adult with a small visual offset. Each family shares one bedroom, queue position and transaction. Families check in, settle in a bedroom, eat, swim, return to their bedroom and then check out. Guests follow clear paths between facilities and visible queue positions. The resort opens with its facilities built. General building construction is deferred.

## What the player controls

| Control | Behavior |
| --- | --- |
| Package price | Choose $90 Budget, $120 Standard or $170 Premium. One price covers the bedroom, buffet and pool. The booking panel shows the selected package, the upcoming booking count and which day the price applies to. |
| Staff assignment | Reception, buffet and pool each have a permanent worker. Assign the fourth worker to any of those stations at any time. An extra worker opens one parallel service slot. Existing service finishes when the float moves, and future guests use the new capacity. |
| Pool terrace | Keep the $420 upgrade visible on Day 1 with the locked state “Available Day 2.” It adds one permanent pool service slot and visibly installs a patio with chairs and an umbrella. Buying it updates the scene, cash and capacity immediately. Show the cost, capacity change and any cash shortfall. |
| Clock | On-screen pause and 1×, 2× and 4× buttons. Revision 2 handles Space globally to toggle pause during play, including when a button has keyboard focus. Keys 1, 2 and 3 select and resume the corresponding speed. |
| Contextual controls | Dock icons open Booking, Staff, Pool, Reviews, Goals or Settings. One panel is visible at a time; X, an outside press or Escape closes it. Escape with no panel opens Settings, which pauses time while preserving manual pause state. Save and Load use one local slot. |
| Explore | Hold the left mouse button and drag, or use the middle mouse button, to move the view. The wheel zooms around the pointer; plus/minus and Home provide visible camera controls. UI interactions do not pan the world. |

Start with **$140**, Standard pricing and the float at the buffet. The welcome screen identifies the resort facilities, names the three objectives and explains that the float helps the longest line. The player can inspect and change price and staffing before the booking window.

## Clock and guests

| Day time | Event |
| --- | --- |
| 00:00–00:19 | The player can change today's package before bookings open. |
| 00:20 | Lock today's price and number of bookings. Budget and Standard book 4 families. Premium books 3. Later changes apply to the next day. |
| 00:20, 00:26, 00:32, 00:38 | Families join reception in arrival order. Omit the last slot on Premium. Charge the locked package price when reception service finishes and reserve one available room per family. |
| From check-in | Walk 4 seconds to the room, settle for 10, walk 4 to the buffet, wait and eat, walk 4 to the pool, wait and swim, then walk 4 back to the room. |
| 03:20, 03:28, 03:36, 03:44 | In arrival order, each family leaves its room for checkout after its visit, then releases the room and submits a review. A 4-second exit walk fits before closing. |
| 04:00 | Deduct $120 payroll, record the day recap and start the next day. After Day 3, stop time and show the final recap. |

Use first-in, first-out queues. Each service slot serves one family for **8 seconds at reception**, **18 at the buffet** or **20 at the pool**. Count wait time from joining a queue to beginning service. Each station starts with one slot. The float and pool upgrade stack. At an event boundary, finish service and release capacity before starting the next queued family. Rooms are assigned automatically in room order.

The first playable has a quiet stretch between the afternoon pool visits and the checkout window. During that time, the player can inspect the resort, prepare the next day's price or staffing, and advance time at 2× or 4×.

## Money and feedback

Each family submits one rating at checkout. The rating is capped between 0 and 100. Start at 92, add the package's value modifier, add 8 if the terrace was installed by the start of that family's pool visit, and subtract the wait penalty for each station.

| Package | Value modifier | Revenue per full day |
| --- | ---: | ---: |
| Budget | +5 | $360 |
| Standard | 0 | $480 |
| Premium | −12 | $510 |

Each station's wait penalty is one point per complete two seconds beyond six seconds, capped at 14 points. A review names its largest wait penalty when one applies. Otherwise, mention the upgraded pool or the package value. Display the average over completed stays to one decimal place and evaluate the goal against the unrounded average. Show a placeholder until the first review arrives.

Show the player the upcoming package's bookings and value modifier, with plain-language cues such as “Better value” for Budget or “Higher expectations” for Premium. Show the assigned station's extra service slot alongside active and waiting family counts. With Standard pricing and the float at the buffet, the busiest Day 1 pool wait is 34 seconds. Assigning the float to the pool before arrivals eliminates the pool wait and moves the longest wait to the buffet (30 seconds). Installing the terrace while keeping the float at the buffet brings every queue wait to six seconds or less.

With Standard bookings and no purchases, the Day 1 closing balance is $500. Buying the terrace at Day 2 opening leaves $80. Budget pricing leaves $380 at Day 1 close and can fund the upgrade after the first Day 2 check-in. The price choice trades off income, occupancy and value ratings.

## What players see and hear

- Keep day, time, cash, completed stays, average rating and pool status visible. Display each station's staffing and waiting count near its label or control.
- Use a check-in movement or status cue, buffet and pool activity, and a review at checkout. Animate walking guests, water and swimmers. The visible terrace change is immediate and legible at the normal camera scale.
- Play unobtrusive looping music and distinct cues for check-in, upgrade and day close. Include a mute control.
- Use readable interface text with high-contrast labels, a visible keyboard focus and button states identified by text or icons as well as color. Keep the whole interface visible at 1280 × 720.

## Save and load

Save the current day and time, active and pending prices, cash, booked and occupied rooms, staff assignment, pool state, guests and service or queue progress, scheduled events, completed reviews and the chosen speed. Save from the menu at any point during the run. Load the same point in a paused state so the player can inspect the resort before resuming. Make the Load button unavailable until a save exists. A missing or unreadable save leaves the current run intact and gives a clear message.
