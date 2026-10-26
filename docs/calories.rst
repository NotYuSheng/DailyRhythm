Calories
========

DailyRhythm can show calories for meals. They are estimates for your own
reference, not nutrition advice.

Where values come from
----------------------

Each food stores its calories per serving and where that value came from.
A meal uses the calories you type for it, or else its food's calories
times the quantity.

.. list-table::
   :header-rows: 1

   * - Source
     - Stored as
     - Licence and use
     - Status
   * - You
     - ``user``
     - Your own entry.
     - Available
   * - `Open Food Facts <https://world.openfoodfacts.org>`_
     - ``off``
     - Database under the `Open Database License (ODbL)
       <https://opendatacommons.org/licenses/odbl/1-0/>`_; individual values
       under the Database Contents License. The app shows "From Open Food
       Facts (ODbL)" with every lookup. Share-alike applies if the data is
       redistributed.
     - Available, online and opt-in
   * - `USDA FoodData Central <https://fdc.nal.usda.gov>`_
     - ``usda``
     - Public domain (CC0 1.0).
     - Planned: bundled for offline search
   * - SG FoodID (Health Promotion Board, Singapore)
     - ``sgfoodid``
     - Its terms allow use in apps with a conspicuous attribution notice and a
       link to the licence, and no implied endorsement by HPB. To be checked
       again before bundling.
     - Planned: bundled for offline search
   * - AI estimate
     - ``estimate``
     - Opt-in; would send only the dish name. Always labelled as an estimate.
     - Planned

Privacy
-------

Looking up calories is optional and only happens when you tap **Look up
calories**. Only the food's name is sent to Open Food Facts; nothing else
about you or your log leaves the device.
