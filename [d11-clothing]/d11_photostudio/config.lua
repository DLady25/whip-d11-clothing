Config = {}

-- Where the character poses for the photo: inside the SubUrban in Del Perro (a game store, always on the map).
-- x, y, z = the character's position (what GetEntityCoords gives) and w = where they face. Another spot: stand there
-- facing the way you want, type /fotospot and paste the vector4 it prints (chat and F8) here.
Config.Ponto = vector4(-1192.94, -772.69, 17.33, 216.0)

-- While taking the photo the player is in a routing bucket of their own: nobody sees or gets in the way, and no
-- pedestrians. The bucket is Config.DimensaoBase + the player's id; they go back to theirs when done.
Config.DimensaoBase = 7000

-- The command that prints the current position as a vector4, to move the spot above (reads only).
Config.ComandoPonto = 'fotospot'
