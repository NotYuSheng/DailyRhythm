Calories
========

DailyRhythm can show calories for meals. They are estimates for your own
reference, not nutrition advice.

Where values come from
----------------------

Each food stores its calories per serving and where that value came from.
A meal uses the calories you type for it, or else its food's calories
times the quantity.

A new food starts with an estimate (below) unless you type its calories.
Change it any time by typing the calories on a meal of that food: from then
on it's yours (``user``).

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
   * - Estimate
     - ``estimate``
     - Offered for every food without calories, worked out on the phone: from
       one of your own foods with calories (the same name, or a dish it
       contains, "Spicy laksa" from "Laksa"), else from the built-in table of
       common foods (``assets/data/common_foods.json``). That table is generic,
       generated once with a language model and reviewed; its values are
       typical servings, not measurements. Always shown as an estimate and
       replaced by anything you type.
     - Available

Privacy
-------

Looking up calories is optional and only happens when you tap **Look up
calories**. Only the food's name is sent to Open Food Facts; nothing else
about you or your log leaves the device.
