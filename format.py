import argparse


def format(file):
    with open(file, 'r') as f:
        data = []
        for line in f:
            line = line.split()
            data.append(line)
        # Change header if needed. Don't remove "\t"
        print('genome,completeness,contamination')
        data_no = data[3:-1]
        for item in data_no:
            # Printing this fields from the file. count starts on "0".
            print('{}.fa,{},{}'.format(item[0], item[12], item[13]))


def args_parse():
    """Parse the args"""
    parser = argparse.ArgumentParser(description="Format blabla")
    parser.add_argument('csv', help="File name")

    return parser.parse_args()


if __name__ == '__main__':
    args = args_parse()
    format(args.csv)
