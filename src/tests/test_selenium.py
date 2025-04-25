from selenium import webdriver
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities

def test_google():
    driver = webdriver.Remote(
        command_executor='http://selenium-hub:4444/wd/hub',
        desired_capabilities=DesiredCapabilities.CHROME)
    driver.get("http://www.google.com")
    assert "Google" in driver.title
    driver.quit()
