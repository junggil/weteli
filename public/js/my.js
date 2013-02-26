$(function() {
    $("#youtube-player").tubeplayer({
        width: 600, // the width of the player
        height: 450, // the height of the player
        allowFullScreen: "true", // true by default, allow user to go full screen
        initialVideo: "", // the video that is loaded into the player
        preferredQuality: "default",// preferred quality: default, small, medium, large, hd720
        onPlay: function(id){}, // after the play method is called
        onPause: function(){}, // after the pause method is called
        onStop: function(){}, // after the player is stopped
        onSeek: function(time){}, // after the video has been seeked to a defined point
        onMute: function(){}, // after the player is muted
        onUnMute: function(){} // after the player is unmuted
    });
});
