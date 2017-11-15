##script to extract the mp3 from a youtube clip. Used for music and audio books.
import youtube_dl

video = input("Enter URL of Youtube video to extract audio from: ")

options = {
    'format':'bestaudio/best',
    'extractaudio': True,
    'audioformat': 'mp3',
    'outtmpl': "%(title)s" + ".%(ext)s", #'%(title)s.%(ext)s', #name the file the Title of the video
    'noplaylist': True,
    'nocheckcertificate': True,
    'postprocessors': [{
        'key': 'FFmpegExtractAudio',
        'preferredcodec': 'mp3',
        'preferredquality': '192',
    }]
}

with youtube_dl.YoutubeDL(options) as ydl:
    ydl.download([video])
