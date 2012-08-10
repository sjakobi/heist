{-|

This module defines a TemplateDirectory data structure for convenient
interaction with templates within web apps.

-}

module Text.Templating.Heist.TemplateDirectory
    ( TemplateDirectory
    , newTemplateDirectory
    , newTemplateDirectory'

    , getDirectoryTS
    , reloadTemplateDirectory
    ) where

------------------------------------------------------------------------------
import           Control.Concurrent
import           Control.Monad
import           Control.Monad.Trans
import           Text.Templating.Heist
import           Text.Templating.Heist.Splices.Cache


------------------------------------------------------------------------------
-- | Structure representing a template directory.
data TemplateDirectory n m
    = TemplateDirectory
        FilePath
        (HeistState n m)
        (MVar (HeistState n m))
        CacheTagState


------------------------------------------------------------------------------
-- | Creates and returns a new 'TemplateDirectory' wrapped in an Either for
-- error handling.
newTemplateDirectory :: FilePath
                     -> HeistState IO IO
                     -> IO (Either String (TemplateDirectory IO IO))
newTemplateDirectory dir templateState = liftIO $ do
    (modTs,cts) <- mkCacheTag
    let origTs = modTs templateState
    ets <- loadTemplates dir origTs
    leftPass ets $ \ts -> do
        tsMVar <- newMVar $ ts
        return $ TemplateDirectory dir origTs tsMVar cts


------------------------------------------------------------------------------
-- | Creates and returns a new 'TemplateDirectory', using the monad's fail
-- function on error.
newTemplateDirectory' :: FilePath
                      -> HeistState IO IO
                      -> IO (TemplateDirectory IO IO)
newTemplateDirectory' = ((either fail return =<<) .) . newTemplateDirectory


------------------------------------------------------------------------------
-- | Gets the 'HeistState' from a TemplateDirectory.
getDirectoryTS :: (Monad m, MonadIO n)
               => TemplateDirectory n m
               -> n (HeistState n m)
getDirectoryTS (TemplateDirectory _ _ tsMVar _) = liftIO $ readMVar $ tsMVar


------------------------------------------------------------------------------
-- | Clears cached content and reloads templates from disk.
reloadTemplateDirectory :: (MonadIO n)
                        => TemplateDirectory n IO
                        -> n (Either String ())
reloadTemplateDirectory (TemplateDirectory p origTs tsMVar cts) = liftIO $ do
    clearCacheTagState cts
    ets <- loadTemplates p origTs
    leftPass ets $ \ts -> modifyMVar_ tsMVar (const $ return ts)


------------------------------------------------------------------------------
-- | Prepends an error onto a Left.
leftPass :: Monad m => Either String b -> (b -> m c) -> m (Either String c)
leftPass e m = either (return . Left . loadError) (liftM Right . m) e
  where
    loadError = (++) "Error loading templates: "
