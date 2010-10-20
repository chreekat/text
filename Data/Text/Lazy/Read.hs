{-# LANGUAGE OverloadedStrings #-}

-- |
-- Module      : Data.Text.Lazy.Read
-- Copyright   : (c) 2010 Bryan O'Sullivan
--
-- License     : BSD-style
-- Maintainer  : bos@serpentine.com, rtomharper@googlemail.com,
--               duncan@haskell.org
-- Stability   : experimental
-- Portability : GHC
--
-- Functions used frequently when reading textual data.
module Data.Text.Lazy.Read
    (
      Reader
    , decimal
    , hexadecimal
    , signed
    , rational
    , double
    ) where

import Control.Monad (liftM)
import Data.Char (digitToInt, isDigit, isHexDigit, ord)
import Data.Ratio
import Data.Text.Lazy as T

-- | Read some text, and if the read succeeds, return its value and
-- the remaining text.
type Reader a = Text -> Either String (a,Text)

-- | Read a decimal integer.
--
-- This function does not handle leading sign characters.  If you need
-- to handle signed input, use @'signed' 'decimal'@.
decimal :: Integral a => Reader a
{-# SPECIALIZE decimal :: Reader Int #-}
{-# SPECIALIZE decimal :: Reader Integer #-}
decimal txt
    | T.null h  = Left "no digits in input"
    | otherwise = Right (T.foldl' go 0 h, t)
  where (h,t)  = T.spanBy isDigit txt
        go n d = (n * 10 + fromIntegral (digitToInt d))

-- | Read a hexadecimal number, with optional leading @\"0x\"@.  This
-- function is case insensitive.
--
-- This function does not handle leading sign characters.  If you need
-- to handle signed input, use @'signed' 'hexadecimal'@.
hexadecimal :: Integral a => Reader a
{-# SPECIALIZE hex :: Reader Int #-}
{-# SPECIALIZE hex :: Reader Integer #-}
hexadecimal txt
    | T.toLower h == "0x" = hex t
    | otherwise           = hex txt
 where (h,t) = T.splitAt 2 txt

-- | Read a leading sign character (@\'-\'@ or @\'+\'@) and apply it
-- to the result of applying the given reader.
signed :: Num a => Reader a -> Reader a
{-# INLINE signed #-}
signed f = runP (signa (P f))

-- | Read a rational number.
--
-- This function accepts an optional leading sign character.
rational :: RealFloat a => Reader a
{-# SPECIALIZE rational :: Reader Double #-}
rational = floaty $ \real frac fracDenom -> fromRational $
                     real % 1 + frac % fracDenom

-- | Read a rational number.
--
-- This function accepts an optional leading sign character.
--
-- /Note/: This function is almost ten times faster than 'rational',
-- but is slightly less accurate.
--
-- The 'Double' type supports about 16 decimal places of accuracy.
-- For 94.2% of numbers, this function and 'rational' give identical
-- results, but for the remaining 5.8%, this function loses precision
-- around the 15th decimal place.  For 0.001% of numbers, this
-- function will lose precision at the 13th or 14th decimal place.
double :: Reader Double
double = floaty $ \real frac fracDenom ->
                   fromIntegral real +
                   fromIntegral frac / fromIntegral fracDenom

hex :: Integral a => Reader a
{-# SPECIALIZE hex :: Reader Int #-}
{-# SPECIALIZE hex :: Reader Integer #-}
hex txt
    | T.null h  = Left "no digits in input"
    | otherwise = Right (T.foldl' go 0 h, t)
  where (h,t)  = T.spanBy isHexDigit txt
        go n d = (n * 16 + fromIntegral (hexDigitToInt d))

hexDigitToInt :: Char -> Int
hexDigitToInt c
    | c >= '0' && c <= '9' = ord c - ord '0'
    | c >= 'a' && c <= 'f' = ord c - (ord 'a' - 10)
    | c >= 'A' && c <= 'F' = ord c - (ord 'A' - 10)
    | otherwise            = error "Data.Text.Lex.hexDigitToInt: bad input"

signa :: Num a => Parser a -> Parser a
{-# SPECIALIZE signa :: Parser Int -> Parser Int #-}
{-# SPECIALIZE signa :: Parser Integer -> Parser Integer #-}
signa p = do
  sign <- perhaps '+' $ char (\c -> c == '-' || c == '+')
  if sign == '+' then p else negate `liftM` p

newtype Parser a = P {
      runP :: Text -> Either String (a,Text)
    }

instance Monad Parser where
    return a = P $ \t -> Right (a,t)
    {-# INLINE return #-}
    m >>= k  = P $ \t -> case runP m t of
                           Left err     -> Left err
                           Right (a,t') -> runP (k a) t'
    {-# INLINE (>>=) #-}
    fail msg = P $ \_ -> Left msg

perhaps :: a -> Parser a -> Parser a
perhaps def m = P $ \t -> case runP m t of
                            Left _      -> Right (def,t)
                            r@(Right _) -> r

char :: (Char -> Bool) -> Parser Char
char p = P $ \t -> case T.uncons t of
                     Just (c,t') | p c -> Right (c,t')
                     _                 -> Left "char"

data T = T !Integer !Int

floaty :: RealFloat a => (Integer -> Integer -> Integer -> a) -> Reader a
{-# INLINE floaty #-}
floaty f = runP $ do
  sign <- perhaps '+' $ char (\c -> c == '-' || c == '+')
  real <- P decimal
  T fraction fracDigits <- perhaps (T 0 0) $ do
    _ <- char (=='.')
    digits <- P $ \t -> Right (fromIntegral . T.length $ T.takeWhile isDigit t, t)
    n <- P decimal
    return $ T n digits
  let e c = c == 'e' || c == 'E'
  power <- perhaps 0 (char e >> signa (P decimal) :: Parser Int)
  let n = if fracDigits == 0
          then if power == 0
               then fromIntegral real
               else fromIntegral real * (10 ^^ power)
          else if power == 0
               then f real fraction (10 ^ fracDigits)
               else f real fraction (10 ^ fracDigits) * (10 ^^ power)
  return $! if sign == '+'
            then n
            else -n