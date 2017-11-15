import requests
import datetime
today = datetime.date.today()
print("Date = " + str(today))
players = {"goaliejordan": "6040022", "rice": "3987504", "deathstrkr14": "6047137"}
for player in players:
    url = "https://api.hotslogs.com/Public/Players/" + players[player]
    response = requests.get(url)
    # print(response.status_code)
    data = response.json()
    name = data["Name"]
    mmrs = data["LeaderboardRankings"]
    if response.status_code == 200:
        print("&&" * len(mmrs[0]["GameMode"] + ": " + str(mmrs[0]["CurrentMMR"])))
        print("Player name: " + name)
        for mmr in mmrs:
            print("*-" * (len(mmr["GameMode"] + ": " + str(mmr["CurrentMMR"]))))
            print(mmr["GameMode"] + ": " + str(mmr["CurrentMMR"]))
        print("&&" * len(mmr["GameMode"] + ": " + str(mmr["CurrentMMR"])))
        print("")
    else:
        print("Something went wrong with the request")