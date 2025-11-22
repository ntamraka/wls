
import os
import pandas as pd
from datetime import datetime
import argparse

def extract_details(file_path):
    # Read the content of the file
    with open(file_path, 'r') as file:
        content = file.read()
        file_name = os.path.basename(file_path)

    # Find the index of "Results:"
    results_index = content.find("Results:")
    if results_index == -1:
        print(f"Error: 'Results:' not found in file {file_path}")
        return None

    try:
        # Extract details from "Results:" to the end of the file
        results_content = content[results_index + len("Results:"):].strip()
        print(results_content)
        # Extract details using regex (assuming the format is consistent)
        if readwriteflag=="read":
            details = {
            'filename': file_name,
            'Op rate': float(results_content.split(':')[1].split()[0].replace(',', '')),
            'Partition rate': float(results_content.split(':')[3].split()[0].replace(',', '')),
            'Row rate': float(results_content.split(':')[5].split()[0].replace(',', '')),
            'Latency mean': float(results_content.split(':')[7].split()[0]),
            'Latency median': float(results_content.split(':')[9].split()[0]),
            'Latency 95th percentile': float(results_content.split(':')[11].split()[0]),
            'Latency 99th percentile': float(results_content.split(':')[13].split()[0]),
            'Latency 99.9th percentile': float(results_content.split(':')[15].split()[0]),
            'Latency max': float(results_content.split(':')[17].split()[0]),
            'Total partitions': float(results_content.split(':')[19].split()[0].replace(',', '')),
            'Total errors': float(results_content.split(':')[21].split()[0].replace(',', '')),
            'Total GC count': float(results_content.split(':')[23].split()[0]),
            'Total GC memory': float(results_content.split(':')[24].split()[0].replace(',', '')),
            'Total GC time': float(results_content.split(':')[25].split()[0]),
            'Avg GC time': results_content.split(':')[26].split()[0],
            'StdDev GC time': float(results_content.split(':')[27].split()[0]),
            'Total operation time': results_content.split(':')[28]+':'+results_content.split(':')[29]+':'+results_content.split(':')[30].split('\n')[0]

        }
        else:
            details = {
            'filename': file_name,
            'Op rate': float(results_content.split(':')[1].split()[0].replace(',', '')),
            'Partition rate': float(results_content.split(':')[4].split()[0].replace(',', '')),
            'Row rate': float(results_content.split(':')[7].split()[0].replace(',', '')),
            'Latency mean': float(results_content.split(':')[10].split()[0]),
            'Latency median': float(results_content.split(':')[13].split()[0]),
            'Latency 95th percentile': float(results_content.split(':')[16].split()[0]),
            'Latency 99th percentile': float(results_content.split(':')[19].split()[0]),
            'Latency 99.9th percentile': float(results_content.split(':')[22].split()[0]),
            'Latency max': float(results_content.split(':')[25].split()[0]),
            'Total partitions': float(results_content.split(':')[28].split()[0].replace(',', '')),
            'Total errors': float(results_content.split(':')[31].split()[0].replace(',', '')),
            'Total GC count': float(results_content.split(':')[34].split()[0]),
            'Total GC memory': float(results_content.split(':')[35].split()[0].replace(',', '')),
            'Total GC time': float(results_content.split(':')[36].split()[0]),
            'Avg GC time': results_content.split(':')[37].split()[0],
            'StdDev GC time': float(results_content.split(':')[38].split()[0]),
            'Total operation time': results_content.split(':')[39]+':'+results_content.split(':')[40]+':'+results_content.split(':')[41].split('\n')[0]

        }
    except IndexError as e:
        print(f"Error processing file {file_path}: {e}")
        print(f"Content of the file:\n{content}")
        return None
    print(details)
    return details

def calculate_average(data_frame):
    # Calculate the average of all numeric columns
    averages = data_frame.drop(columns=['filename']).sum(numeric_only=True)

    # Add a new row with the average values
    average_row = {'filename': 'Average'}
    average_row.update(averages)
    data_frame = data_frame.append(average_row, ignore_index=True)

    return data_frame
def convert_to_float_or_none(value):
    # Remove non-numeric characters before attempting to convert
    numeric_value = ''.join(char for char in value if char.isdigit() or char in {'-', '.', 'e', 'E'})
    try:
        return float(numeric_value)
    except ValueError:
        return None


def process_files(directory):
    data_frames = []

    # Iterate through files in the directory
    for file_name in os.listdir(directory):
        if file_name.endswith('.txt'):
            file_path = os.path.join(directory, file_name)

            # Extract details from each file
            details = extract_details(file_path)

            if details is not None:
                # Create a DataFrame for each file
                data_frames.append(pd.DataFrame([details]))

    # Concatenate DataFrames into a single DataFrame
    result_df = pd.concat(data_frames, ignore_index=True)

    return result_df

def save_to_excel(data_frame, output_path):
    data_frame.to_excel(output_path, index=False)
def save_to_csv(data_frame, output_path):
    data_frame.to_csv(output_path, index=False)

if __name__ == "__main__":
    # Specify the directory containing the output files
    parser = argparse.ArgumentParser(description='Process output files and generate summary')
    parser.add_argument('-d', '--output-directory', type=str, default='output', help='Specify the output directory path')
    parser.add_argument('-n', '--summary-name', type=str, default='summary', help='Specify the output directory path')
    parser.add_argument('-f', '--readwriteflag', type=str, default='readwrite', help='Specify the output directory path')
    args = parser.parse_args()

    # Specify the directory containing the output files
    output_directory = args.output_directory
    output_name = args.summary_name
    readwriteflag=args.readwriteflag

    # Process files and create a DataFrame
    result_df = process_files(output_directory)

    if not result_df.empty:
        # Calculate the average and append it to the DataFrame
        result_df = calculate_average(result_df)

        current_datetime = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        output_excel_path = f'cassandra_{output_name}_{current_datetime}.csv'
        save_to_csv(result_df, output_excel_path)


        final_csv_path = 'final_summary.csv'
        result_df2 = pd.read_csv(final_csv_path)
        print(result_df2)
        average_row_df = result_df[result_df['filename'] == "Average"]

        average_row_df['filename']=output_excel_path
        #average_row_df.loc[result_df2['filename'] == 'Average', 'filename'] = output_excel_path

        updated_df = pd.concat([result_df2, average_row_df], ignore_index=True)
        updated_df.to_csv(final_csv_path, index=False)

        
    
        #print(updated_df)
        print(f"Data saved to {output_excel_path}")
    else:
        print("No valid data to save.")
