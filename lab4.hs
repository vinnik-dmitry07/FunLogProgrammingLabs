import Data.Char
import Data.Maybe (fromJust, isJust, isNothing)
import Data.List (map, filter, elem, find, nub)
import Data.Map (Map, (!))
import qualified Data.Map as Map (fromList, toList, keys, member)
import qualified Data.Set as Set (fromList)
import Debug.Trace

combos [] = [[]]
combos ([]:ls) = combos ls
combos ((h:t):ls) = map (h:) (combos ls) ++ combos (t:ls)

rules_ =
  Map.fromList
    [ ('S', ["A", ""])
    , ('A', ["CBEx", "CEEE"])
    , ('B', ["CSRSD", "bbb"])
    , ('C', [""])
    , ('D', ["dd", ""])
    , ('E', ["e"])
    , ('R', ["A"])
    ]

is_nonterm symbol = isUpper symbol
is_term symbol = not $ is_nonterm symbol

get_eps_nont rules = do
  let rules_list = Map.toList rules
  let has_eps = nub $ map fst $ filter (\(_, r) -> elem "" r) $ rules_list
  let rules_new = Map.fromList [(l, map (remove_eps has_eps) r) | (l, r) <- rules_list]
  if rules_new == rules then has_eps else get_eps_nont rules_new

eps_nont = get_eps_nont rules_

remove_eps eps_nont word = filter (\symbol -> not $ elem symbol eps_nont) word

split_by symbol word = [(before_s, after_s) | (s, i) <- zip word [0..], s == symbol, let before_s = take i word, let after_s = drop (i+1) word]
rules_with symbol = [(l, r') | (l, r) <- Map.toList rules_, let r' = filter (elem symbol) r, not $ null r']

get_next_words symbols_list = do
  --traceShowM ("    get_next_words", symbols_list)

  -- Replace each symbol according to the rule
  -- Each Char -> [String]
  let parts_of_words = map (\symbol -> if elem symbol (Map.keys rules_) then rules_ ! symbol else [[symbol]]) symbols_list
  --traceShowM ("parts_of_words", parts_of_words)

  -- parts_to_cobine = [[part11, part12, ...], [part21, part22, part23, ...]] where part :: String
  let parts_of_words' = [[remove_eps eps_nont part | part <- parts] | parts <- parts_of_words]
  --traceShowM ("parts_of_words'", parts_of_words')

  -- combos parts_of_words' = [[part11, part21, part31], [part11, part21, part32], ..., []] where part :: String
  -- init removes []
  -- nub removes same
  -- map concat: [[part11, part21, part31], [part11, part21, part32], ...] -> [part11 ++ part21 ++ part31, part11 ++ part21 ++ part32, ...]
  let next_words = map concat $ sequence parts_of_words'
  --traceShowM ("next_words", next_words)

  next_words

get_minumal_nont_word words_ = do
  --traceShowM ("words_", words_)

  let iterator = iterate (concatMap get_next_words) words_
  --traceShowM ("iterator", take 4 $ iterator)

  let iterator' = map (Set.fromList . concat) (scanl1 (++) [words_n | words_n <- iterator])
  --traceShowM ("iterator'", take 4 $ iterator')

  let (res, _, _) = fromJust (find (\(i, i', i1') -> (any (all is_term) i) || (i' == i1')) (zip3 iterator iterator' (drop 1 iterator')))
  --traceShowM ("res",  res)

  find (all is_term) res
  --let nont_words = filter (all is_term) words'
  --traceShowM ("nont_words", nont_words)

  --if not $ null nont_words then Just minimum $ nont_words else Nothing
  --
  --traceShowM ("nont_words", nont_words)

get_symbol_info symbol = do
  let rules_with_symbol = rules_with symbol
  --traceShowM ("rules_with_symbol " ++ [symbol], rules_with_symbol)

  [(l, fromJust a'') | (l, r) <- rules_with_symbol, word <- r,
             (b, a) <- split_by symbol word,
             let b' = remove_eps eps_nont b, b' == "",
             let a' = remove_eps eps_nont a,
             let a'' = get_minumal_nont_word [a'], isJust a'']

get_words_minlength symbol = do
  let iterator =
        iterate
          (\steps_list ->
            [(nonterms ++ [new_nonterm], wi ++ wi') |
              (nonterms, wi) <- steps_list,
              (new_nonterm, wi') <- get_symbol_info $ last nonterms,
              (not $ elem new_nonterm nonterms) ||
              (last nonterms /= symbol && new_nonterm == symbol)])
          [([symbol], "")]
  --traceShowM ("iterator", take 5 $ iterator)

  let iterator' = takeWhile (/= []) $ drop 1 $ iterator
  --traceShowM ("iterator'", take 5 $ iterator')

  find (\(nonterms, w) -> head nonterms == symbol && last nonterms == symbol) $ concat $ iterator'

f1 guess_res not_compl new_res = do
  let guesses =
        Map.fromList
          [(
            l,
            [foldl
              (\su x ->
                su +
                  if is_term x
                    then 1
                    else
                      if (Map.member x guess_res) && (isJust $ guess_res ! x)
                        then fromJust $ guess_res ! x
                        else 0)
              0 word | word <- r ]
          ) | (l, r) <- Map.toList not_compl]

  let m = [(l, minimum $ zip r r1) | ((l, r), (l1, r1)) <- zip (Map.toList $ guesses) (Map.toList not_compl)]

  let fi = find (\e -> all isJust $ map (\x -> new_res ! x) $ snd $ snd e) m

  if isJust fi
    then do
      let res = fromJust fi
      (fst res, fst $ snd $ res)
  else do
    let guess_res' =
          Map.fromList
            [(l, r'') |
              (l, r) <- Map.toList new_res,
              let r' = minimum $ guesses ! l,
              let r'' =
                    if Map.member l guesses
                      then if (r' /= 0) then Just r' else Nothing
                      else r]
    f1 guess_res' not_compl new_res

f2 res = do
  let not_compl = Map.fromList [(l, r) | (l, r) <- Map.toList rules_, isNothing $ res ! l]
  --traceShowM $ not_compl

  let (nont, len) = f1 res not_compl res
  --traceShowM (nont, len)

  Map.fromList [(l, r') | (l, r) <- Map.toList res, let r' = if l == nont then Just len else r]

get_min_len = do
  let step1 =
        Map.fromList
          [(l, r') |
            (l, r) <- Map.toList rules_,
            let r' =
                  if any (=="") r
                    then Just 0
                    else
                      if all (all is_term) r
                        then Just $ minimum $ map length $ r
                        else Nothing]
  takeWhile (any (isNothing . snd) . Map.toList) $ iterate f2 step1

main = do
  let nonterms = ['S', 'A', 'B', 'C', 'D', 'E']

  --traceShowM ("rules_", rules_)
  --traceShowM ("eps_nont", eps_nont)
  print get_min_len
  --mapM_ print $
  --  zip
  --    nonterms
  --    (map
  --      (\x ->
  --        if isJust x
  --          then
  --            let res = snd $ fromJust x
  --            in Just (res, length $ res)
  --          else Nothing)
  --      (map get_words_minlength $ nonterms))
