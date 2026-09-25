using Toybox.Application;
using Toybox.Test;

import Toybox.Lang;


// premium/source is on premium.jungle's sourcePath and on no other, so this file is compiled
// into the Premium build alone (#135). It is here to prove exactly that: that the directory
// compiles, and that it stays out of Lite. It was written before any Premium feature had put
// code there; TimeSize (#32) is the first. On Lite's path it would run in the Lite suite and fail on the Lite name.
//
// It asserts that premium/resources-base/strings/strings.xml overrides Lite's AppName, which
// is what gives the Premium build a name of its own on the watch.
(:test)
function premiumSourceStaysOutOfLite(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(
        Application.loadResource(Rez.Strings.AppName), "MatrixTime Premium",
        "premium/source is compiled only into Premium, which is named MatrixTime Premium");
    return true;
}
