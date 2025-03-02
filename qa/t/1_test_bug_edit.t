# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.

use strict;
use warnings;
use lib qw(lib ../../lib ../../local/lib/perl5);

use Test::More "no_plan";

use QA::Util;

my ($sel, $config) = get_selenium();

log_in($sel, $config, 'admin');
set_parameters($sel, {"Bug Fields" => {"usestatuswhiteboard-on" => undef}});

# Clear the saved search, in case this test didn't complete previously.
$sel->click_ok('quicksearch_top');
if ($sel->is_element_present(
  '//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]'))
{
  $sel->click_ok(
    '//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]');
  $sel->wait_for_page_to_load_ok(WAIT_TIME);
  $sel->title_is("Bug List: My bugs from QA_Selenium");
  $sel->click_ok('forget-search', 'Forget Search');
  $sel->wait_for_page_to_load_ok(WAIT_TIME);
  $sel->title_is("Search is gone");
  $sel->is_text_present_ok("OK, the My bugs from QA_Selenium search is gone");
}

# Just in case the test failed before completion previously, reset the CANEDIT bit.
go_to_admin($sel);
$sel->click_ok("link=Groups");
check_page_load($sel, q{http://HOSTNAME/editgroups.cgi});
$sel->title_is("Edit Groups");
$sel->click_ok("link=Master");
check_page_load($sel,
  q{http://HOSTNAME/editgroups.cgi?action=changeform&group=30});
$sel->title_is("Change Group: Master");
my $group_url = $sel->get_location();
$group_url =~ /group=(\d+)$/;
my $master_gid = $1;

clear_canedit_on_testproduct($sel, $master_gid);
logout($sel);

# First create a bug.

log_in($sel, $config, 'QA_Selenium_TEST');
file_bug_in_product($sel, 'TestProduct');
$sel->type_ok("short_desc", "Test bug editing");
$sel->type_ok("comment",    "ploc");
$sel->click_ok("commit");
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=__BUG_ID__});
my $bug1_id = $sel->get_value('//input[@name="id" and @type="hidden"]');
$sel->is_text_present_ok('has been added to the database',
  "Bug $bug1_id created");

# Now edit field values of the bug you just filed.

go_to_bug($sel, $bug1_id);
$sel->select_ok("rep_platform", "label=Other");
$sel->select_ok("op_sys",       "label=Other");

# QA_Selenium_TEST does not have editbugs so we make sure
# the following fields are not editable
ok(!$sel->is_element_present('//select[@name="priority"]'),
  'Priority field not editable');
ok(!$sel->is_element_present('//select[@name="bug_type"]'),
  'Bug type field not editable');
ok(!$sel->is_element_present('//select[@name="bug_severity"]'),
  'Severity field not editable');

$sel->type_ok("bug_file_loc",      "foo.cgi?action=bar");
$sel->type_ok("status_whiteboard", "[Selenium was here]");
$sel->type_ok("comment",           "new comment from me :)");
$sel->select_ok("bug_status", "label=RESOLVED");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# Test emoji comment reactions.

my $reactions_base_path = '//div[@class="comment-reactions"]';
my $reactions_anchor_path = $reactions_base_path . '/button[@class="anchor"]';
my $reactions_picker_path = $reactions_base_path . '/div[@class="picker"]';
my $reactions_sums_path = $reactions_base_path . '/div[@class="sums"]';
my $reactions_btn1_path = '/button[@data-reaction-name="+1"]';
my $reactions_btn2_path = '/button[@data-reaction-name="smile"]';

# Disable reactions
log_in($sel, $config, 'admin');
set_parameters($sel, {"Advanced" => {"use_comment_reactions-off" => undef}});
logout($sel);

# Reactions are now hidden
go_to_bug($sel, $bug1_id);
ok(!$sel->is_element_present($reactions_base_path));

# Enable reactions
log_in($sel, $config, 'admin');
set_parameters($sel, {"Advanced" => {"use_comment_reactions-on" => undef}});
logout($sel);

# Reactions are now visible
log_in($sel, $config, 'QA_Selenium_TEST');
go_to_bug($sel, $bug1_id);
$sel->is_element_present_ok($reactions_base_path);
$sel->click_ok($reactions_anchor_path);
$sel->click_ok($reactions_picker_path . $reactions_btn1_path
  . '[@aria-pressed="false"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="1"][@aria-pressed="true"]');
$sel->click_ok($reactions_anchor_path);
$sel->is_element_present_ok($reactions_picker_path . $reactions_btn1_path
  . '[@aria-pressed="true"]');
$sel->click_ok($reactions_picker_path . $reactions_btn2_path
  . '[@aria-pressed="false"]');
$sel->click_ok($reactions_sums_path . $reactions_btn2_path
  . '[@data-reaction-count="1"][@aria-pressed="true"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn2_path
  . '[@data-reaction-count="0"][@aria-pressed="false"]');
logout($sel);

# Choose comment reactions by a different user. No privilege required to react
log_in($sel, $config, 'unprivileged');
go_to_bug($sel, $bug1_id);
$sel->click_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="1"][@aria-pressed="false"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="2"][@aria-pressed="true"]');
$sel->click_ok($reactions_anchor_path);
$sel->click_ok($reactions_picker_path . $reactions_btn1_path
  . '[@aria-pressed="true"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="1"][@aria-pressed="false"]');
$sel->click_ok($reactions_anchor_path);
$sel->click_ok($reactions_picker_path . $reactions_btn2_path
  . '[@aria-pressed="false"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn2_path
  . '[@data-reaction-count="1"][@aria-pressed="true"]');
logout($sel);

# Restrict comments on the bug to users in the editbugs group
log_in($sel, $config, 'admin');
go_to_bug($sel, $bug1_id);
$sel->check_ok('restrict_comments');
$sel->click_ok('bottom-save-btn', 'Save changes');
logout($sel);

# An unprivileged user cannot react but can see reactions
log_in($sel, $config, 'unprivileged');
go_to_bug($sel, $bug1_id);
ok(!$sel->is_element_present($reactions_anchor_path));
ok(!$sel->is_element_present($reactions_picker_path));
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="1"][@aria-pressed="false"][@disabled]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn2_path
  . '[@data-reaction-count="1"][@aria-pressed="true"][@disabled]');
logout($sel);

# An editbugs user can still react
log_in($sel, $config, 'editbugs');
go_to_bug($sel, $bug1_id);
$sel->click_ok($reactions_anchor_path);
$sel->click_ok($reactions_picker_path . $reactions_btn1_path
  . '[@aria-pressed="false"]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="2"][@aria-pressed="true"]');
logout($sel);

# Restore comment restriction
log_in($sel, $config, 'admin');
go_to_bug($sel, $bug1_id);
$sel->uncheck_ok('restrict_comments');
$sel->click_ok('bottom-save-btn', 'Save changes');
logout($sel);

# A logged out user cannot react but can see reactions of other users
go_to_bug($sel, $bug1_id);
ok(!$sel->is_element_present($reactions_anchor_path));
ok(!$sel->is_element_present($reactions_picker_path));
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn1_path
  . '[@data-reaction-count="2"][@aria-pressed="false"][@disabled]');
$sel->is_element_present_ok($reactions_sums_path . $reactions_btn2_path
  . '[@data-reaction-count="1"][@aria-pressed="false"][@disabled]');

# Now move the bug into another product, which has a mandatory group.

log_in($sel, $config, 'QA_Selenium_TEST');
go_to_bug($sel, $bug1_id);
$sel->select_ok("product",   "label=QA-Selenium-TEST");
$sel->select_ok("component", "label=QA-Selenium-TEST");
$sel->type_ok("comment", "moving to QA-Selenium-TEST");
$sel->click_ok('bottom-save-btn', 'Save changes');
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");

go_to_bug($sel, $bug1_id);
$sel->select_ok("rep_platform", "label=All");
$sel->select_ok("op_sys",       "label=All");
$sel->click_ok("add-cc-btn", "Show add cc field");
$sel->type_ok("add-cc",  $config->{admin_user_login});
$sel->type_ok("comment", "Unchecking the reporter_accessible checkbox");

# This checkbox is checked by default.
$sel->click_ok("reporter_accessible");
$sel->select_ok("bug_status", "label=VERIFIED");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
go_to_bug($sel, $bug1_id);
$sel->type_ok("comment",
  "I am the reporter, but I can see the bug anyway as I belong to the mandatory group"
);
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# The admin is not in the mandatory group, but they have been CC'ed,
# so they can view and edit the bug (as they have editbugs privs by inheritance).

log_in($sel, $config, 'admin');
go_to_bug($sel, $bug1_id);
$sel->check_ok('//input[@name="bug_type" and @value="defect"]');
$sel->select_ok("bug_severity", "label=blocker");
$sel->select_ok("priority",     "label=Highest");
$sel->type_ok("status_whiteboard", "[Selenium was here][admin too]");
$sel->select_ok("bug_status", "label=CONFIRMED");
$sel->type_ok("assigned_to", $config->{admin_user_login});
$sel->type_ok("comment",     "I have editbugs privs. Taking!");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");

go_to_bug($sel, $bug1_id);
$sel->click_ok("add-cc-btn", "Show add cc field");
$sel->type_ok("add-cc", $config->{unprivileged_user_login});
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# The powerless user can see the restricted bug, as they have been CC'ed.

log_in($sel, $config, 'unprivileged');
go_to_bug($sel, $bug1_id);
$sel->is_text_present_ok("I have editbugs privs. Taking!");
logout($sel);

# Now turn off cclist_accessible, which will prevent
# the powerless user to see the bug again.

log_in($sel, $config, 'admin');
go_to_bug($sel, $bug1_id);
$sel->click_ok("cclist_accessible");
$sel->type_ok("comment",
  "I am allowed to turn off cclist_accessible despite not being in the mandatory group"
);
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# The powerless user cannot see the restricted bug anymore.

log_in($sel, $config, 'unprivileged');
$sel->type_ok("quicksearch_top", $bug1_id);
$sel->submit("quicksearch_top");
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->title_is("Access Denied");
$sel->is_text_present_ok("You are not authorized to access bug $bug1_id");
logout($sel);

# Move the bug back to TestProduct, which has no group restrictions.

log_in($sel, $config, 'admin');
go_to_bug($sel, $bug1_id);
$sel->select_ok("product",   "label=TestProduct");
$sel->select_ok("component", "label=TestComponent");

# When selecting a new product, Bugzilla tries to reassign the bug by default,
# so we have to uncheck it.
$sel->click_ok("set-default-assignee");
$sel->uncheck_ok("set-default-assignee");
$sel->type_ok("comment", "-> Moving back to Testproduct.");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
$sel->title_is("Verify New Product Details...");
$sel->is_text_present_ok(
  "These groups are not legal for the 'TestProduct' product or you are not allowed to restrict bugs to these groups"
);
$sel->is_element_present_ok(
  '//input[@type="checkbox" and @name="groups" and @value="QA-Selenium-TEST"]');
ok(
  !$sel->is_editable(
    '//input[@type="checkbox" and @name="groups" and @value="QA-Selenium-TEST"]'),
  "QA-Selenium-TEST group not editable"
);
ok(
  !$sel->is_checked(
    '//input[@type="checkbox" and @name="groups" and @value="QA-Selenium-TEST"]'),
  "QA-Selenium-TEST group not selected"
);
$sel->is_element_present_ok(
  '//input[@type="checkbox" and @name="groups" and @value="Master"]');
$sel->is_editable_ok(
  '//input[@type="checkbox" and @name="groups" and @value="Master"]',
  "Master group is editable");
ok(
  !$sel->is_checked(
    '//input[@type="checkbox" and @name="groups" and @value="Master"]'),
  "Master group not selected by default"
);
$sel->click_ok("change_product");
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
go_to_bug($sel, $bug1_id);
$sel->click_ok("cclist_accessible");
$sel->type_ok("comment",
  "I am allowed to turn off cclist_accessible despite not being in the mandatory group"
);
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# The unprivileged user can view the bug again, but cannot
# edit it, except adding comments.

log_in($sel, $config, 'unprivileged');
go_to_bug($sel, $bug1_id);
$sel->type_ok("comment",
  "I have no privs, I can only comment (and remove myself from the CC list)");
ok(!$sel->is_element_present('//select[@name="product"]'),
  "Product field not editable");
ok(!$sel->is_element_present('//select[@name="bug_type"]'),
  "Type field not editable");
ok(!$sel->is_element_present('//select[@name="bug_severity"]'),
  "Severity field not editable");
ok(!$sel->is_element_present('//select[@name="priority"]'),
  "Priority field not editable");
ok(!$sel->is_element_present('//select[@name="op_sys"]'),
  "OS field not editable");
ok(!$sel->is_element_present('//select[@name="rep_platform"]'),
  "Hardware field not editable");
$sel->click_ok("cc-summary");

# display all links for removing a cc list member
$sel->driver->execute_script('
  var remove_cc_elements = document.getElementsByClassName("cc-remove");
  for (var i = 0; i < remove_cc_elements.length; i++) {
    remove_cc_elements[i].removeAttribute("style");
  }');
$sel->click_ok('//a[@class="cc-remove" and @data-login="'
    . $config->{unprivileged_user_login}
    . '"]');
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# Now let's test the CANEDIT bit.

log_in($sel, $config, 'admin');
edit_product($sel, "TestProduct");
$sel->click_ok("link=Edit Group Access Controls:");
check_page_load($sel,
  q{http://HOSTNAME/editproducts.cgi?action=editgroupcontrols&product=TestProduct}
);
$sel->title_is("Edit Group Controls for TestProduct");
$sel->check_ok("canedit_$master_gid");
$sel->click_ok("submit");
check_page_load($sel, q{http://HOSTNAME/editproducts.cgi});
$sel->title_is("Update group access controls for TestProduct");

# The user is in the master group, so they can comment.

go_to_bug($sel, $bug1_id);
$sel->type_ok("comment", "Do nothing except adding a comment...");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");
logout($sel);

# This user is not in the master group, so they cannot comment.

log_in($sel, $config, 'QA_Selenium_TEST');
go_to_bug($sel, $bug1_id);
$sel->type_ok("comment", "Just a comment too...");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
$sel->title_is("Product Edit Access Denied");
$sel->is_text_present_ok(
  "You are not permitted to edit bugs in product TestProduct.");
logout($sel);

# Test searches.

log_in($sel, $config, 'admin');
open_advanced_search_page($sel);
screenshot_page($sel, '/app/artifacts/line259.png');
$sel->remove_all_selections_ok("product");
$sel->select_ok("product", "label=TestProduct");
$sel->remove_all_selections_ok("bug_status");
$sel->remove_all_selections_ok("resolution");
screenshot_page($sel, '/app/artifacts/line264.png');
$sel->is_checked_ok("emailassigned_to1");
$sel->select_ok("emailtype1", "value=exact");
$sel->type_ok("email1", $config->{admin_user_login});
$sel->check_ok("emailassigned_to2");
$sel->check_ok("emailqa_contact2");
$sel->check_ok("emailcc2");
$sel->select_ok("emailtype2", "value=exact");
$sel->type_ok("email2", $config->{QA_Selenium_TEST_user_login});
screenshot_page($sel, '/app/artifacts/line271.png');
$sel->click_ok("Search");
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?emailreporter2=1&order=Importance&emailtype2=exact&list_id=__LIST_ID__&emailtype1=exact&emailcc2=1&emailassigned_to1=1&query_format=advanced&emailqa_contact2=1&email2=QA-Selenium-TEST%40mozilla.test&emailassigned_to2=1&email1=admin%40mozilla.test&product=TestProduct}
);
$sel->title_is("Bug List");
screenshot_page($sel, '/app/artifacts/line275.png');
$sel->is_text_present_ok("One bug found.");
$sel->type_ok("save_newqueryname", "My bugs from QA_Selenium");
$sel->click_ok("remember");
# Bad test below, unable to deterministically know the inner list_id encoded in the newquery param.
# check_page_load($sel,
#   q{http://HOSTNAME/buglist.cgi?newquery=email1%3Dadmin%2540mozilla.test%26email2%3DQA-Selenium-TEST%2540mozilla.test%26emailassigned_to1%3D1%26emailassigned_to2%3D1%26emailcc2%3D1%26emailqa_contact2%3D1%26emailreporter2%3D1%26emailtype1%3Dexact%26emailtype2%3Dexact%26list_id%3D15%26product%3DTestProduct%26query_format%3Dadvanced%26order%3Dpriority%252Cbug_severity&cmdtype=doit&remtype=asnamed&token=1531926552-dc69995d79c786af046436ec6717000b&newqueryname=My+bugs+from+QA_Selenium&list_id=__LIST_ID__}
# );
$sel->title_is("Search created");
$sel->is_text_present_ok(
  "OK, you have a new search named My bugs from QA_Selenium.");
$sel->click_ok(
  '//a[normalize-space(text())="My bugs from QA_Selenium" and not(@role="option")]'
);
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?cmdtype=runnamed&namedcmd=My+bugs+from+QA_Selenium&list_id=__LIST_ID__}
);
$sel->title_is("Bug List: My bugs from QA_Selenium");
logout($sel);

# Let's create a 2nd bug by this user so that we can test mass-change
# using the saved search the admin just created.

log_in($sel, $config, 'QA_Selenium_TEST');
file_bug_in_product($sel, 'TestProduct');
$sel->type_ok("short_desc", "New bug from me");

# We turned on the CANEDIT bit for TestProduct.
$sel->type_ok("comment", "I can enter a new bug, but not edit it, right?");
$sel->click_ok('commit');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=__BUG_ID__});
my $bug2_id = $sel->get_value('//input[@name="id" and @type="hidden"]');
$sel->is_text_present_ok('has been added to the database',
  "Bug $bug2_id created");

# Clicking the "Back" button and resubmitting the form again should trigger a suspicous action error.

$sel->go_back_ok();
check_page_load($sel,
  q{http://HOSTNAME/enter_bug.cgi?product=TestProduct&format=__default__});
$sel->title_is("Enter Bug: TestProduct");
$sel->click_ok("commit");
check_page_load($sel, q{http://HOSTNAME/post_bug.cgi});
$sel->title_is("Suspicious Action");
$sel->is_text_present_ok("you have no valid token for the create_bug action");
$sel->click_ok('//input[@value="Confirm Changes"]');
check_page_load($sel, q{http://HOSTNAME/show_bug.cgi?id=__BUG_ID__});
$sel->is_text_present_ok('has been added to the database', 'Bug created');
$sel->type_ok("comment", "New comment not allowed");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
$sel->title_is("Product Edit Access Denied");
$sel->is_text_present_ok(
  "You are not permitted to edit bugs in product TestProduct.");
logout($sel);

# Reassign the newly created bug to the admin.

log_in($sel, $config, 'admin');
go_to_bug($sel, $bug2_id);
$sel->type_ok("assigned_to", $config->{admin_user_login});
$sel->type_ok("comment",     "Taking!");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug2_id});
$sel->is_text_present_ok("Changes submitted for bug $bug2_id");

# Test mass-change.

$sel->click_ok('quicksearch_top');
$sel->click_ok(
  '//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]');
screenshot_page($sel, '/app/artifacts/line344.png');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?cmdtype=runnamed&namedcmd=My+bugs+from+QA_Selenium&list_id=__LIST_ID__}
);
screenshot_page($sel, '/app/artifacts/line346.png');
$sel->title_is("Bug List: My bugs from QA_Selenium");
screenshot_page($sel, '/app/artifacts/line348.png');
$sel->is_text_present_ok("2 bugs found");
screenshot_page($sel, '/app/artifacts/line350.png');
$sel->click_ok('change-several');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?email1=admin%40mozilla.test&email2=QA-Selenium-TEST%40mozilla.test&emailassigned_to1=1&emailassigned_to2=1&emailcc2=1&emailqa_contact2=1&emailreporter2=1&emailtype1=exact&emailtype2=exact&product=TestProduct&query_format=advanced&order=priority%2Cbug_severity&tweak=1&list_id=__LIST_ID__}
);
$sel->title_is("Bug List");
$sel->click_ok("check_all");
$sel->type_ok("comment", 'Mass change"');
$sel->select_ok("bug_status", "label=RESOLVED");
$sel->select_ok("resolution", "label=WORKSFORME");
$sel->click_ok('commit', 'Save changes');
check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
$sel->title_is("Bugs processed");

go_to_bug($sel, $bug1_id);
$sel->selected_label_is("resolution", "WORKSFORME");
$sel->select_ok("resolution", "label=INVALID");
$sel->click_ok('bottom-save-btn', 'Save changes');
check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
$sel->is_text_present_ok("Changes submitted for bug $bug1_id");

go_to_bug($sel, $bug1_id);
$sel->selected_label_is("resolution", "INVALID");

$sel->click_ok('action-menu-btn', 'Expand action menu');
$sel->click_ok('action-history',  'Show bug history');

# Clicking history opens a new tab
my $windows = $sel->driver->get_window_handles;
$sel->driver->switch_to_window($windows->[1]);
check_page_load($sel, qq{http://HOSTNAME/show_activity.cgi?id=$bug1_id});
$sel->is_text_present_ok("URL foo.cgi?action=bar");
$sel->is_text_present_ok("Severity -- blocker");
$sel->is_text_present_ok(
  "Whiteboard [Selenium was here] [Selenium was here][admin too]");
$sel->is_text_present_ok("Product QA-Selenium-TEST TestProduct");
$sel->is_text_present_ok("Status CONFIRMED RESOLVED");

# Close tab and switch back
$sel->driver->close;
$sel->driver->switch_to_window($windows->[0]);

# Last step: move bugs to another DB, if the extension is enabled.

# if ($config->{test_extensions}) {
#     set_parameters($sel, { "Bug Moving" => {"move-to-url"     => {type => "text", value => 'http://www.foo.com/'},
#                                             "move-to-address" => {type => "text", value => 'import@foo.com'},
#                                             "movers"          => {type => "text", value => $config->{admin_user_login}}
#                                            }
#                          });
#
#     # Mass-move has been removed, see 581690.
#     # Restore these tests once this bug is fixed.
#     # $sel->click_ok('quicksearch_top');
#     # $sel->click_ok('//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]');
#     # $sel->wait_for_page_to_load_ok(WAIT_TIME);
#     # $sel->title_is("Bug List: My bugs from QA_Selenium");
#     # $sel->is_text_present_ok("2 bugs found");
#     # $sel->click_ok('change-several', 'Change Several Bugs at Once');
#     # $sel->wait_for_page_to_load_ok(WAIT_TIME);
#     # $sel->title_is("Bug List");
#     # $sel->click_ok("check_all");
#     # $sel->type_ok("comment", "-> moved");
#     # $sel->click_ok('oldbugmove');
#     # $sel->wait_for_page_to_load_ok(WAIT_TIME);
#     # $sel->title_is("Bugs processed");
#     # $sel->is_text_present_ok("Bug $bug1_id has been moved to another database");
#     # $sel->is_text_present_ok("Bug $bug2_id has been moved to another database");
#     # go_to_bug($sel, $bug2_id);
#     # $sel->selected_label_is("resolution", "MOVED");
#
#     go_to_bug($sel, $bug2_id);
#     $sel->click_ok('oldbugmove');
#     $sel->wait_for_page_to_load_ok(WAIT_TIME);
#     $sel->is_text_present_ok("Changes submitted for bug $bug2_id");
#     go_to_bug($sel, $bug2_id);
#     $sel->selected_label_is("resolution", "MOVED");
#     $sel->is_text_present_ok("Bug moved to http://www.foo.com/.");
#
#     # Disable bug moving again.
#     set_parameters($sel, { "Bug Moving" => {"movers" => {type => "text", value => ""}} });
# }

# Make sure token checks are working correctly for single bug editing and mass change,
# first with no token, then with an invalid token.

foreach my $params (["no_token_single_bug", ""],
  ["invalid_token_single_bug", "&token=1"])
{
  my ($comment, $token) = @$params;
  $sel->open_ok("/process_bug.cgi?id=$bug1_id&comment=$comment$token",
    undef, "Edit a single bug with " . ($token ? "an invalid" : "no") . " token");
  $sel->title_is("Suspicious Action");
  $sel->is_text_present_ok($token ? "an invalid token" : "web browser directly");
  $sel->click_ok("confirm");
  check_page_load($sel, qq{http://HOSTNAME/show_bug.cgi?id=$bug1_id});
  $sel->is_text_present_ok("Changes submitted for bug $bug1_id");
  go_to_bug($sel, $bug1_id);
  $sel->is_text_present_ok($comment);
}

foreach my $params (["no_token_mass_change", ""],
  ["invalid_token_mass_change", "&token=1"])
{
  my ($comment, $token) = @$params;
  $sel->open_ok(
    "/process_bug.cgi?id_$bug1_id=1&id_$bug2_id=1&comment=$comment$token",
    undef, "Mass change with " . ($token ? "an invalid" : "no") . " token");
  $sel->title_is("Suspicious Action");
  $sel->is_text_present_ok("no valid token for the buglist_mass_change action");
  $sel->click_ok("confirm");
  check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
  $sel->title_is("Bugs processed");
  foreach my $bug_id ($bug1_id, $bug2_id) {
    go_to_bug($sel, $bug_id);
    $sel->is_text_present_ok($comment);
    next if $bug_id == $bug2_id;
    $sel->go_back_ok();
    check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
    $sel->title_is("Bugs processed");
  }
}

# Now move these bugs out of our radar.

$sel->click_ok('quicksearch_top');
$sel->click_ok(
  '//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?cmdtype=runnamed&namedcmd=My+bugs+from+QA_Selenium&list_id=__LIST_ID__}
);
$sel->title_is("Bug List: My bugs from QA_Selenium");
$sel->is_text_present_ok("2 bugs found");
$sel->click_ok('change-several', 'Change Several Bugs at Once');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?email1=admin%40mozilla.test&email2=QA-Selenium-TEST%40mozilla.test&emailassigned_to1=1&emailassigned_to2=1&emailcc2=1&emailqa_contact2=1&emailreporter2=1&emailtype1=exact&emailtype2=exact&product=TestProduct&query_format=advanced&order=priority%2Cbug_severity&tweak=1&list_id=__LIST_ID__}
);
$sel->title_is("Bug List");
$sel->click_ok("check_all");
$sel->type_ok("comment",     "Reassigning to the reporter");
$sel->type_ok("assigned_to", $config->{QA_Selenium_TEST_user_login});
$sel->click_ok("commit");
check_page_load($sel, q{http://HOSTNAME/process_bug.cgi});
$sel->title_is("Bugs processed");

# Now delete the saved search.

$sel->click_ok('quicksearch_top');
$sel->click_ok(
  '//a[normalize-space(text())="My bugs from QA_Selenium" and @role="option"]');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?cmdtype=runnamed&namedcmd=My+bugs+from+QA_Selenium&list_id=__LIST_ID__}
);
$sel->title_is("Bug List: My bugs from QA_Selenium");
$sel->click_ok('forget-search', 'Forget Search');
check_page_load($sel,
  q{http://HOSTNAME/buglist.cgi?cmdtype=dorem&remaction=forget&namedcmd=My+bugs+from+QA_Selenium&token=1531926582-f228fa8ebc2f2b3970f2a791e54534ec&list_id=__LIST_ID__}
);
$sel->title_is("Search is gone");
$sel->is_text_present_ok("OK, the My bugs from QA_Selenium search is gone");

# Reset the CANEDIT bit. We want it to be turned off by default.
clear_canedit_on_testproduct($sel, $master_gid);
logout($sel);

sub clear_canedit_on_testproduct {
  my ($sel, $master_gid) = @_;

  edit_product($sel, "TestProduct");
  $sel->click_ok("link=Edit Group Access Controls:");
  check_page_load($sel,
    q{http://HOSTNAME/editproducts.cgi?action=editgroupcontrols&product=TestProduct}
  );
  $sel->title_is("Edit Group Controls for TestProduct");
  $sel->uncheck_ok("canedit_$master_gid");
  $sel->click_ok("submit");
  check_page_load($sel, q{http://HOSTNAME/editproducts.cgi});
  $sel->title_is("Update group access controls for TestProduct");
}
