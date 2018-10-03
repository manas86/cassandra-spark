#
# Bare minimum to ensure the Spark installation seems to be okay and can start properly.
# This is intended to be run by spark-submit
#
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()
print("Spark master is: %s" % spark.sparkContext.master)
