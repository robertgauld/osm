@my_account
@osm

Feature: OSM
    As a user of the site
    In order to use the site
    I want to be able to access my data on OSM

    Background:
	Given I have no users
        And I have the following user records
	    | email_address     | name  |
	    | alice@example.com | Alice |
        And "alice@example.com" is an activated user account


    Scenario: Connect to OSM Account
        Given an OSM request to "authorize" will work
        When I signin as "alice@example.com" with password "P@55word"
        Then I should see "You need to connect your account to your OSM account."
        And I should see "You have not yet connected your account to your OSM account"
        When I follow "Connect now"
        Then I should be on the connect_to_osm page
        When I fill in "Email" with "alice@example.com"
        And I fill in "Password" with "password"
        And I press "Connect to OSM"
        Then I should be on the connect_to_osm2 page
        And I should see "Sucessfully connected to your OSM account."
        And "alice@example.com" should be connected to OSM

    Scenario: Connect to OSM Account (API Error)
        Given an OSM request to "authorize" will not work
        When I signin as "alice@example.com" with password "P@55word"
        And I go to the connect_to_osm page
        And I fill in "Email" with "alice@example.com"
        And I fill in "Password" with "password"
        And I press "Connect to OSM"
        Then I should be on the connect_to_osm page
        And I should not see "Sucessfully connected to your OSM account."
        And I should see "A simulated OSM API error occured"
        And "alice@example.com" should not be connected to OSM