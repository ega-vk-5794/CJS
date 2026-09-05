* E018  CJSMIG-697  ZCL_E018_NOC_TRANS_CHEM_LOGIC
* The class had NO ACTIVE VERSION - a string constant does not take an empty literal, so every earlier fix was in the source and none of it was running
*
* Retype this in SE24. It is your journey's own class,
* not the framework - nothing is pushed for you.

* --- private section --------------------------------------------------
*   was:  constants C_IMPEXP type STRING value ''.       <- will not compile
  constants C_IMPEXP type STRING value IS INITIAL ##NO_TEXT.

* Activate the class after this and re-test the whole journey - including the
* CX_SY_CONVERSION_NO_NUMBER on post, which may go with it.
