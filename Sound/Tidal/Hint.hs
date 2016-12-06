module Sound.Tidal.Hint where

import Sound.Tidal.Context

import Language.Haskell.Interpreter as Hint

data Response = OK {parsed :: ParamPattern}
              | Error {errorMessage :: String}

instance Show Response where
  show (OK p) = "Ok: " ++ show p
  show (Error s) = "Error: " ++ s

{-
runJob :: String -> IO (Response)
runJob job = do putStrLn $ "Parsing: " ++ job
                result <- hintParamPattern job
                let response = case result of
                      Left err -> Error (show err)
                      Right p -> OK p
                return response
-}

libs = ["Prelude","Sound.Tidal.Context","Sound.OSC.Type","Sound.OSC.Datum"]

{-
hintParamPattern  :: String -> IO (Either InterpreterError ParamPattern)
hintParamPattern s = Hint.runInterpreter $ do
  Hint.set [languageExtensions := [OverloadedStrings]]
  Hint.setImports libs
  Hint.interpret s (Hint.as :: ParamPattern)
-}

hintJob  :: (MVar String, MVar Response) -> IO ()
hintJob (mIn, mOut) =
  do result <- do Hint.runInterpreter $ do
                  Hint.set [languageExtensions := [OverloadedStrings]]
                  --Hint.setImports libs
                  Hint.setImportsQ $ (Prelude.map (\x -> (x, Nothing)) libs) ++ [("Data.Map", Nothing)]
                  hintLoop
     let response = case result of
          Left err -> Error (parseError err)
          Right p -> OK p -- can happen
         parseError (UnknownError s) = "Unknown error: " ++ s
         parseError (WontCompile es) = "Compile error: " ++ (intercalate "\n" (Prelude.map errMsg es))
         parseError (NotAllowed s) = "NotAllowed error: " ++ s
         parseError (GhcException s) = "GHC Exception: " ++ s
         parseError _ = "Strange error"

     takeMVar mIn
     putMVar mOut response
     hintJob (mIn, mOut)
     where hintLoop = do s <- liftIO (readMVar mIn)
                         liftIO $ putStrLn $ "compiling " ++ s
                         -- check <- typeChecks s
                         --interp check s
                         interp True s
                         hintLoop
           interp True s = do p <- Hint.interpret s (Hint.as :: ParamPattern)
                              liftIO $ putMVar mOut $ OK p
                              liftIO $ takeMVar mIn
                              return ()
           interp False _ = do liftIO $ putMVar mOut $ Error "Didn't typecheck"
                               liftIO $ takeMVar mIn
                               return ()

