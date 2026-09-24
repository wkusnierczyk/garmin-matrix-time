using Toybox.Application;
using Toybox.Test;

import Toybox.Lang;


// The edition exclusions, guarded from the one resource the two editions are known to
// disagree on: the application name (#135).
//
// Each build excludes the other edition's annotation by appending it to monkey.jungle's
// exclusion list -- lite.jungle appends (:premium), premium.jungle appends (:lite). A
// jungle layered after the edition jungle that replaced the list instead would drop that
// exclusion without a word, and Lite would carry Premium code or the reverse. So each test
// below is annotated with one edition and asserts that edition's name: compiled into the
// other edition's suite, it fails there. Neither exclusion can be dropped quietly.
//
// Unit tests are stripped from a release build, so this file leaves the Lite release PRG
// byte for byte what it was ("make check-lite").
(:test :lite)
function liteDeclarationsStayOutOfPremium(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(
        Application.loadResource(Rez.Strings.AppName), "MatrixTime",
        "a (:lite) declaration is compiled only into Lite, which is named MatrixTime");
    return true;
}


(:test :premium)
function premiumDeclarationsStayOutOfLite(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(
        Application.loadResource(Rez.Strings.AppName), "MatrixTime Premium",
        "a (:premium) declaration is compiled only into Premium, which is named MatrixTime Premium");
    return true;
}
