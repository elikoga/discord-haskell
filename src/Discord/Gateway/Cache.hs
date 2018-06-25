{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_HADDOCK prune, not-home #-}

-- |Query info about connected Guilds and Channels
module Discord.Gateway.Cache where

import Data.List (foldl')
import Data.Monoid ((<>))
import Control.Concurrent.MVar
import Control.Concurrent.Chan
import qualified Data.Map.Strict as M

import Discord.Types

data Cache = Cache
            { _currentUser :: Maybe User
            , _dmChannels :: M.Map Snowflake Channel
            , _guilds :: M.Map Snowflake Guild
            , _channels :: M.Map (Snowflake,Snowflake) Channel
            } deriving (Show)

emptyCache :: IO (MVar Cache)
emptyCache = newMVar (Cache Nothing M.empty M.empty M.empty)

addEvent :: MVar Cache -> Chan Event -> Chan String -> IO ()
addEvent cache eventChan log = loop
  where
  loop :: IO ()
  loop = do
    event <- readChan eventChan
    minfo <- takeMVar cache
    writeChan log ("cache - " <> show (adjustCache minfo event))
    putMVar cache (adjustCache minfo event)
    loop

adjustCache :: Cache -> Event -> Cache
adjustCache minfo event = case event of
  Ready (Init _ user dmChannels guilds _) ->
    let dmChans = M.fromList (zip (map channelId dmChannels) dmChannels)
        g = M.fromList (zip (map guildId guilds) guilds)
    in Cache (Just user) dmChans g M.empty
  --ChannelCreate Channel
  --ChannelUpdate Channel
  --ChannelDelete Channel
  GuildCreate guild ->
    let g = M.insert (guildId guild) (guild {- UPDATE channels field of guild (like _channels of Cache)-}) (_guilds minfo)
        c = foldl' (\m (k,v) -> M.insert k v m)
                                M.empty
                                [ ((guildId guild, channelId ch), if isGuildChannel ch then ch { channelGuild=guildId guild} else ch) | ch <- guildChannels guild ]
    in minfo { _guilds = g, _channels = c }
  --GuildUpdate guild -> do
  --  let g = M.insert (guildId guild) guild (_guilds minfo)
  --      m2 = minfo { _guilds = g }
  --  putMVar cache m2
  --GuildDelete guild -> do
  --  let g = M.delete (guildId guild) (_guilds minfo)
  --      c = M.filterWithKey (\(keyGuildId,_) _ -> keyGuildId /= guildId guild) (_channels minfo)
  --      m2 = minfo { _guilds = g, _channels = c }
  --  putMVar cache m2
  _ -> minfo
