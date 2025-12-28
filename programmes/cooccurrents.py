"""Description:
    Compute Lafon specificity of cooccurrent tokens of a given target. This will
    count the words occurring in before/after window within the sentence in
    which they appear.

    The input format is :
        - one (supposedly linguistic) item per line
        - empty lines separate sentences

    Tool emulation:
    By default, this will give results compatible with neither TXM nor itrameur.
    You can switch use the --tool-emulation switch to provide results that
    should be closer with what you get form other tools at equivalent
    configuration. This is not perfect and results might be slightly different
    from the actual tool, this was done by trial and error.

    Feedback:
    This script will output some feedback because processing might take some
    time. Feedback is written on stderr and can be omitted by redirecting stderr
    to /dev/null. It will not affect neither greping nor writing to a file.

Usage examples:
    python cooccurrents.py -h
    python cooccurrents.py *.txt --target foo
    python cooccurrents.py *.txt --target foo > out.tsv 2> /dev/null
    python cooccurrents.py a/*.txt b/*.txt -N 50 -p acknowledge
    python cooccurrents.py *.txt --target "(foo|bar)" --match-mode regex
    python cooccurrents.py *.txt --target foo --tool-emulation itrameur
    python cooccurrents.py *.txt --target foo --tool-emulation TXM

Requirements:
    python>=3.10
"""

import string
import re
import itertools
import typing
import sys
import time, datetime

from collections import Counter, deque
from pathlib import Path

from math import log10


# workaround to avoid regex dependency and keep script self-contained
__punctuations = re.compile("[" + re.escape(string.punctuation) + "«»…" + "]+")

__tool_delta = {
    'itrameur': -1.0,
}

match_strategy = {
    'exact': str.__eq__,
    'regex': re.fullmatch
}


# No tqdm to keep scripts autonomous.
# this is not good code, but allows anyone to launch script on inputs that
# take some time to have very basic feedback
def progress(x):
    start = time.time()
    data = list(x) + [None]
    L = len(data) - 1
    for i, dat in enumerate(data):
        if i != L:
            print(f"{100*i/L:.2f}%", end='\r', file=sys.stderr)
            yield dat
        else:
            print(f"100.00% in {datetime.timedelta(seconds=time.time()-start)}", file=sys.stderr)
            return


def flatten(iterable: typing.Iterable) -> list:
    return list(itertools.chain.from_iterable(iterable))


def log_binomial(n: int, k: int) -> float:
    n = int(n)
    k = int(k)

    if n < 0 or k < 0:
        raise ValueError('binomial: found number < 0')
    if k > n:
        raise ValueError('binomial: k > n')

    if k == 0 or k == n:
        return 0.0

    result = 0
    K = min(k, n - k)
    for i in range(K):
        result += log10(n - i) - log10(i + 1)
    return result


def log_hypergeometric(T: int, t: int, F: int, f: int) -> float:
    a = log_binomial(F, f)
    b = log_binomial(T - F, t - f)
    c = log_binomial(T, t)
    return a + b - c


def lafon_specificity(T: int, t: int, F: int, f: int, tool_emulation: str = 'None') -> float:
    """
    Compute Lafon specificity given corpus and subcorpus counts. Internally, it
    uses a symmetry in the hypergeometric formula for a quicker computation.

    See:
        - Lafon, P. (1980). Sur la variabilité de la fréquence des formes dans un corpus. Mots (1), 127-165.

    Parameters
    ----------
    T : int
        The size of the corpus in number of tokens.
    t : int
        Size of the subcorpus in number of tokens. t < T
    F : int
        Number of times the target token appears in the corpus. F <= T
    f : int
        Number of times the target token appears in the subcorpus. f <= min(t, F)
    tool_emulation : string = 'None'
        None, TXM or itrameur. Aims to provide results this tool would have given with the same configuration.
    """

    if any((t < 0, T < 0, f < 0, F < 0)):
        raise ValueError('Lafon specificity: found count < 0')

    if t > T:
        if tool_emulation == 'itrameur': return 0.0
        raise ValueError('token count greater than corpus size')
    if f > t:
        if tool_emulation == 'itrameur': return 0.0
        raise ValueError('token count greater than subcorpus size')
    if f > F:
        if tool_emulation == 'itrameur': return 0.0
        raise ValueError('token subcorpus count greater than token corpus count')
    if t > T:
        if tool_emulation == 'itrameur': return 0.0
        raise ValueError('subcorpus bigger than corpus')

    # using a symmetry in hypergeometric distribution that is quicker to compute
    specif = log_hypergeometric(T, F, t, f) + __tool_delta.get(tool_emulation, 0.0)

    if log10(f + 1) > log10(t + 1) + log10(F + 1) - log10(T + 2):
        specif = -specif

    return specif


def read_corpus(
    sources: list[str | Path],
    target : str,
    punctuations: str = 'ignore',
    case_sensitivity: str = 'sensitive',
    match: typing.Callable = str.__eq__,
) -> tuple[list, list, list]:

    tokens: list[str] = []
    sentences: list[tuple[int, int]] = []
    target_indices: list[int] = []
    start = 0
    end = 0
    ignore_punctuations = punctuations == 'ignore'
    do_fold = case_sensitivity in ('i', 'insensitive')

    for source in progress(sources):
        with open(source, encoding='utf-8') as input_stream:
            for line in input_stream:
                line = line.strip()
                if line:
                    if ignore_punctuations and __punctuations.fullmatch(line):
                        continue
                    if do_fold:
                        line = line.casefold()
                    tokens.append(line)
                    if match(target, line):
                        target_indices.append(end)
                    end += 1
                else:
                    if end > start:
                        sentences.append((start, end))
                        start = end
            if end > start:
                sentences.append((start, end))
                start = end

    return tokens, sentences, target_indices


def get_counts(
    tokens: list[str],
    sentences: list[tuple[int,int]],
    target_indices: list[int],
    context_length: int,
    ignore_sentences : bool = False,
    tool_emulation: str='None',
):

    T = len(tokens)
    t = 0
    Fs = Counter(tokens)
    fs = Counter()
    fs_tmp = Counter()

    sents = []
    indices = deque(target_indices)
    if not ignore_sentences:
        for sentence in sentences:
            start, end = sentence
            sents.append([sentence, []])
            while indices and start <= indices[0] < end:
                sents[-1][1].append(indices.popleft())
            if not sents[-1][1]:
                sents.pop()
            if not indices:
                break

        for sentence, indices in sents:
            start, end = sentence
            for idx in indices:
                lst = [
                    item
                    for item in range(
                        max(idx - context_length, start),
                        min(idx + context_length + 1, end)
                    )
                    if item != idx
                ]
                fs_tmp.update(lst)
    else:
        start, end = 0, len(tokens)
        for idx in indices:
            lst = [
                item
                for item in range(
                    max(idx - context_length, start),
                    min(idx + context_length + 1, end)
                )
                if item != idx
            ]
            fs_tmp.update(lst)

    if tool_emulation == 'itrameur':
        for idx, count in fs_tmp.most_common():
            fs[tokens[idx]] += count
    else:
        fs.update(tokens[idx] for idx in fs_tmp.keys())
    t = sum(fs.values())

    return T, t, Fs, fs


def run(
    inputs: list[str | Path],
    target: str,
    match_mode: str='exact',
    n_firsts: int = 1000,
    punctuations: str = 'ignore',
    case_sensitivity: str = 'sensitive',
    context_length: int = 10,
    min_frequency: int = 1,
    min_cofrequency: int = 1,
    ignore_sentences : bool = False,
    tool_emulation: str = 'None',
) -> None:

    if tool_emulation == 'itrameur':
        given_punctuations = punctuations
        given_context_length = context_length

        # Ugly workaround to approximate itrameur behaviour.
        # In itrameur, tokens are separated by delimiters (punctuations, but also
        # spaces). There cannot be two consecutive tokens. This is an optimistic
        # approximation because tokens may be separated by multiple delimiters.
        context_length = context_length // 2
        punctuations = 'ignore'

        if given_punctuations != punctuations:
            print(
                f"WARNING: itrameur emulation => punctuations set to {punctuations}\n",
                file=sys.stderr
            )

    elif tool_emulation == 'TXM':
        given_ignore_sentences = ignore_sentences

        ignore_sentences = True
        if given_ignore_sentences != ignore_sentences:
            print(
                f"WARNING: TXM emulation => ignore_sentences set to {ignore_sentences}\n",
                file=sys.stderr
            )

    if context_length < 1:
        raise ValueError(f"Context length should be at least 1, but is {context_length}")

    print("Reading...", file=sys.stderr)

    tokens, sentences, target_indices = read_corpus(
        inputs, target, punctuations, case_sensitivity, match=match_strategy[match_mode]
    )

    T, t, Fs, fs = get_counts(
        tokens, sentences, target_indices, context_length, ignore_sentences=ignore_sentences, tool_emulation=tool_emulation
    )

    print("Computing specificities...", file=sys.stderr)

    filteredin = Counter()  # for more accurate log
    for token, count in fs.most_common():
        if count < min_cofrequency: break
        if Fs[token] < min_frequency: continue
        filteredin[token] = count

    data = []
    for token, count in progress(filteredin.most_common()):
        data.append((
            token,
            Fs[token],
            filteredin[token],
            lafon_specificity(
                T, t, Fs[token], filteredin[token], tool_emulation=tool_emulation
            )
        ))

    data.sort(key=lambda x: -x[-1])

    target_count = len(target_indices)  # works for both exact and regex match
    target_shapes = set(tokens[idx] for idx in target_indices)
    shape_counts = sorted([[shape, Fs[shape]] for shape in target_shapes], key=lambda x: -x[1])
    if match_mode == 'regex':
        target = f'{match_mode}={target}'
        shape_counts.insert(0, [target, target_count])

    print(file=sys.stderr)
    print('target', 'frequency', sep='\t', file=sys.stderr)
    for shape, count in shape_counts:
        print(shape, count, sep='\t', file=sys.stderr)
    print(file=sys.stderr)

    print('token', 'corpus size', 'all contexts size', 'frequency', 'co-frequency', 'specificity', sep='\t')

    n_firsts = (n_firsts if n_firsts > 0 else len(data))
    for token, tok_F, tok_f, tok_specif in data[:n_firsts]:
        print(token, T, t, tok_F, tok_f, f'{tok_specif:.2f}', sep='\t')


def main(argv=None):
    import argparse

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument('inputs', nargs='+', help='The parts of the corpus (list of files/folders)')
    parser.add_argument('--target', required=True, help='The target item')
    parser.add_argument(
        '--match-mode',
        choices=('exact', 'regex'),
        default='exact',
        help='Exact match mode performs string comparison, regex mode performs a full match.'
    )
    parser.add_argument(
        '-N',
        '--n-firsts',
        type=int,
        default=1000,
        help='Output n first elements in terms of rank in the global corpus (default: %(default)s)',
    )
    parser.add_argument(
        '-p',
        '--punctuations',
        choices=('ignore', 'acknowledge'),
        default='ignore',
        help='What to do with punctuations? (default: %(default)s)'
    )
    parser.add_argument(
        '-s',
        '--case-sensitivity',
        choices=('sensitive', 's', 'insensitive', 'i'),
        default='sensitive',
        help='Set case sensitivity (default: %(default)s)',
    )
    parser.add_argument(
        '-l', '--context-length', type=int, default=10, help='left/right context (default: %(default)s)'
    )
    parser.add_argument(
        '-f', '--min-frequency', type=int, default=1, help='Minimal frequency of token to compute specificity (default: %(default)s)'
    )
    parser.add_argument(
        '-c', '--min-cofrequency', type=int, default=0, help='Minimal co-frequency of token to compute specificity (default: %(default)s)'
    )
    parser.add_argument(
        '-t',
        '--tool-emulation',
        choices=('None', 'itrameur', 'TXM'),
        default='None',
        help='Try to emulate the results of the given tool (default: %(default)s)',
    )
    parser.add_argument(
        '-i',
        '--ignore-sentences',
        action='store_true',
        help='Ignore sentence bounds when counting cooccurrents.',
    )

    args = parser.parse_args(argv)
    run(**vars(args))


if __name__ == '__main__':
    main()
    sys.exit(0)
